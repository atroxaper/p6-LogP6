unit module LogP6;

# TODO
# (1). add support of '' (default) writers and filters (create them at start)
# (2). add START support (create default)
# (3). add STOP support (close all writers)
# (4). add EXPORT strategy (one for configuring, one for getting)
# (5). logger wrappers and sync
# (7). cliche factories
# (9). improve writer format
# (12). add methods for logger
# (14). add support custom writer (sql or so)
# (15). add support of str format (lazy creation of msg)
# (16). improve logger log method to be more lazy
# (17). improve ndc and mdc logic in Context and Logger (many loggers)
# 10. tests tests tests
# 8. improve exceptions
# 11. docs docs docs
# 13. add 'turn off' logger (in cliche and Logger)
# 18. add database writer
# 6. init from file
# 19. add trace-some methods in logger
# 20. add backup/restore ndc and mdc
# 21. add params for %trait in pattern
# 22. try make entities immutable (filters, writes, loggers)
# 23. rename sync logger to auto-update logger or so

use UUID;

use LogP6::Logger;
use LogP6::LoggerPure;
use LogP6::LoggerSyncTime;
use LogP6::Writer;
use LogP6::Filter;
use LogP6::Level;
use LogP6::ThreadLocal;
use LogP6::Pattern;

our $trace is export(:configure) = Level::trace;
our $debug is export(:configure) = Level::debug;
our $info  is export(:configure) = Level::info;
our $warn  is export(:configure) = Level::warn;
our $error is export(:configure) = Level::error;

my Lock \lock .= new;

my @cliches = [];
my $cliches-names = SetHash.new;
my %cliches-to-loggers = %();
my %loggers-pure = %();
my %loggers = %();

my Str \default-pattern = "default %msg";
die "wrong default lib pattern <$(default-pattern)>"
	unless Grammar.parse(default-pattern);
my Level \default-level = $info;
my $sync-strategy = Any;

sub initialize() {
	cliche(name => '', matcher => /.*/,
			grooves => (writer(name => ''), filter(name => '')));
}

sub set-sync-strategy(Str $strategy-name) is export(:configure) {
	$sync-strategy = $strategy-name;
}

my role GroovesPartsManager[$lock, $part-name, ::Type, ::NilType] {
	has %!parts = %();

	multi method create(Str :$name, *%fields) {
		with $name {
			return $lock.protect({
				die "$part-name with name $name already exists" with %!parts{$name};
				%!parts{$name} = Type.new: :$name, |%fields;
			});
		} else {
			return Type.new: |%fields;
		}
	}

	multi method create(NilType:D $part) {
		my $name = $part.name;
		die "Name or $part-name have to be defined" without $name;
		return $lock.protect({
			die "$part-name with name $name already exists" with %!parts{$name};
			%!parts{$name} = $part;
		});
	}

	method update(Str:D :$name!, *%fields) {
		$lock.protect({
			die "there is no $part-name with name $name" without %!parts{$name};
			my $old = %!parts{$name}:delete;
			my %new-fields = %();
			for %fields.kv -> $f-name, $f-value {
				%new-fields{$f-name} = $f-value // $old."$f-name"();
			}
			my $new = self.create(:$name, |%new-fields);
			update-loggers(find-cliche-with($name, $part-name));
			return $old;
		});
	}

	multi method replace(Str:D :$name!, *%fields) {
		$lock.protect({
			my $old = %!parts{$name}:delete;
			my $new = self.create(:$name, |%fields);
			update-loggers(find-cliche-with($name, $part-name));
			return $old // NilType;
		});
	}

	multi method replace(NilType:D $part) {
		my $name = $part.name;
		die "Name or $part-name have to be defined" without $name;
		$lock.protect({
			my $old = %!parts{$name}:delete;
			%!parts{$name} = $part;
			update-loggers(find-cliche-with($name, $part-name));
			return $old // NilType;
		});
	}

	method remove(Str:D :$name!) {
		die "remove default $part-name is prohibited" if $name eq '';
		$lock.protect({
			my $old = %!parts{$name}:delete;
			with $old {
				my @found := find-cliche-with($old.name, $part-name);
				for @found -> $old-cliche {
					my $new-cliche = $old-cliche
							.copy-with-new($old.name, '', $part-name);
					change-cliche($old-cliche, $new-cliche);
				}
				update-loggers(@found);
			}
			return $old // NilType;
		});
	}

	method get(Str:D $name) {
		$lock.protect({ %!parts{$name} // NilType });
	}

	method put(NilType:D $part) {
		$lock.protect({ %!parts{$part.name} = $part });
	}

	method all() {
		$lock.protect({ return %!parts.clone; });
	}
}

my $filter-manager =
		GroovesPartsManager[lock, 'filter', FilterConfStd, FilterConf].new;
my $writer-manager =
		GroovesPartsManager[lock, 'writer', WriterConfStd, WriterConf].new;

sub get-filter(Str:D $name --> FilterConf) is export(:configure) {
	$filter-manager.get($name);
}

sub level(Level:D $level --> FilterConf:D) is export(:configure) {
	$filter-manager.create(:$level);
}

proto filter(| --> FilterConf) is export(:configure) { * }

multi sub filter(
		Str :$name,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check
		--> FilterConf:D
) {
	$filter-manager.create(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
		Str :$name,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check,
		Bool:D :$create! where *.so
		--> FilterConf:D
) {
	$filter-manager.create(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
	FilterConf:D $filter,
	--> FilterConf:D) {
	$filter-manager.create($filter);
}

multi sub filter(
	FilterConf:D $filter,
	Bool:D :$create! where *.so
	--> FilterConf:D) {
	$filter-manager.create($filter);
}

multi sub filter(
		Str:D :$name!,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check,
		Bool:D :$update! where *.so
		--> FilterConf:D
) {
	$filter-manager.update(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
		Str:D :$name!,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check,
		Bool:D :$replace! where *.so
		--> FilterConf
) {
	$filter-manager.replace(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
	FilterConf:D $filter,
	Bool:D :$replace! where *.so
	--> FilterConf:D) {
	$filter-manager.replace($filter);
}

multi sub filter(Str:D :$name!, Bool:D :$remove! where *.so --> FilterConf) {
	$filter-manager.remove(:$name);
}

sub get-writer(Str:D $name --> WriterConf) is export(:configure) {
	$writer-manager.get($name);
}

proto writer(| --> WriterConf) is export(:configure) { * }

multi sub writer(
		Str :$name,
		Str :$pattern,
		Bool :$auto-exceptions,
		IO::Handle :$handle
		--> WriterConf:D
) {
	$writer-manager.create(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
		Str :$name,
		Str :$pattern,
		Bool :$auto-exceptions,
		IO::Handle :$handle,
		Bool:D :$create! where *.so
		--> WriterConf:D
) {
	$writer-manager.create(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
		WriterConf:D $writer,
		--> WriterConf:D
) {
	$writer-manager.create($writer);
}

multi sub writer(
		WriterConf:D $writer,
		Bool:D :$create! where *.so
		--> WriterConf:D
) {
	$writer-manager.create($writer);
}

multi sub writer(
		Str:D :$name!,
		Str :$pattern,
		IO::Handle :$handle,
		Bool :$auto-exceptions,
		Bool:D :$update! where *.so
		--> WriterConf:D
) {
	$writer-manager.update(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
		Str:D :$name!,
		Str :$pattern,
		IO::Handle :$handle,
		Bool :$auto-exceptions,
		Bool:D :$replace! where *.so
		--> WriterConf
) {
	$writer-manager.replace(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
	WriterConf:D $writer,
	Bool:D :$replace! where *.so
	--> WriterConf:D) {
	$writer-manager.replace($writer);
}

multi sub writer(Str:D :$name!, Bool:D :$remove! where *.so --> WriterConf) {
	$writer-manager.remove(:$name);
}

sub get-cliche(Str:D $name --> LogP6::Cliche) is export(:configure) {
	lock.protect({
		@cliches.grep(*.name eq $name).first // LogP6::Cliche;
	});
}

proto cliche(| --> LogP6::Cliche) is export(:configure) { * }

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	Level :$default-level, Str :$default-pattern, Positional :$grooves
	--> LogP6::Cliche:D
) {
	cliche(:$name, :$matcher, :$default-level, :$default-pattern, :$grooves,
			:create);
}

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	Level :$default-level, Str :$default-pattern, Positional :$grooves,
	:$create! where *.so --> LogP6::Cliche:D
) {
	lock.protect({
		die "cliche with name $name already exists" if $cliches-names{$name};
		my $cliche = create-cliche(:$name, :$matcher, :$default-level,
				:$default-pattern, :$grooves);
		$cliches-names{$name} = True;
		@cliches.push: $cliche;
		update-loggers;
		$cliche;
	});
}

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	Level :$default-level, Str :$default-pattern, Positional :$grooves,
	:$replace! where *.so --> LogP6::Cliche
) {
	lock.protect({
		my $new = create-cliche(:$name, :$matcher, :$default-level,
				:$default-pattern, :$grooves);
		for @cliches.kv -> $i, $old {
			if $old.name eq $name {
				@cliches[$i] = $new;
				update-loggers;
				return $old;
			}
		}
		$cliches-names{$name} = True;
		@cliches.push: $new;
		update-loggers;
		LogP6::Cliche;
	});
}

multi sub cliche(Str:D :$name!, :$remove! where *.so --> LogP6::Cliche) {
	die "remove default cliche is prohibited" if $name eq '';
	lock.protect({
		return LogP6::Cliche without $cliches-names{$name};
		my $old = @cliches.grep(*.name eq $name).first // LogP6::Cliche;
		@cliches = @cliches.grep(*.name ne $name).Array;
		$cliches-names{$name} = False;
		%cliches-to-loggers = %();
		update-loggers;
		$old;
	});
}

sub create-cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	Level :$default-level, Str :$default-pattern, Positional :$grooves
) {
	die "wrong default pattern <$default-pattern>"
			unless check-pattern($default-pattern);
	my $grvs = ($grooves // (),)>>.List.flat;
	die "grooves must have even amount of elements" unless $grvs %% 2;

	check-part(WriterConf, 'writer', $writer-manager, $_) for $grvs[0,2...^*];
	check-part(FilterConf, 'filter', $filter-manager, $_) for $grvs[1,3...^*];
	self-check-part($_) for |$grvs;

	my $writers-names = $grvs[0,2...^*]>>.&get-part-name($writer-manager).List;
	my $filters-names = $grvs[1,3...^*]>>.&get-part-name($filter-manager).List;

	LogP6::Cliche.new(:$name, :$default-level, :$default-pattern,
			:$matcher, writers => $writers-names, filters => $filters-names);
}

sub get-part-name($part, $type-manager) {
	return $part if $part ~~ Str;
	return $part.name with $part.name;
	my $clone = $part.clone-with-name(UUID.new.Str);
	$type-manager.put($clone);
	return $clone.name;
}

sub check-part(::T, $type, $type-manager,
		$part where $part.defined && ($part.WHAT ~~ Str || $part.WHAT ~~ T)
) {
	if $part ~~ Str {
		die "$type with name $part does not exist" without $type-manager.get($part);
	} else {
		with $part.name -> $pname {
			die "$type with name $pname are not stored"
					without $type-manager.get($pname);
		}
	}
}

sub self-check-part($conf) {
	if $conf !~~ Str {
		$conf.self-check;
	}
}

sub check-pattern(Str $pattern) {
	return True without $pattern;
	so Grammar.parse($pattern);
}

sub find-cliche-with(Str:D $name!,
		Str:D $type where * ~~ any('writer', 'filter') --> List:D
) {
	@cliches.grep(*.has($name, $type)).list;
}

multi sub update-loggers(Positional:D $cliches) {
	for |$cliches -> $cliche {
		for (%cliches-to-loggers{$cliche.name} // SetHash.new).keys -> $trait {
			create-and-store-logger($trait);
		}
	}
}

multi sub update-loggers() {
	my @traits := %loggers.keys.List;
	for @traits -> $trait {
		create-and-store-logger($trait);
	}
}

sub change-cliche($old-cliche, $new-cliche) {
	for @cliches.kv -> $i, $cliche {
		if $cliche.name eq $old-cliche.name {
			@cliches[$i] = $new-cliche;
			return;
		}
	}
	die "can not chnage cliche with name $($old-cliche.name)";
}

sub create-logger($trait, $cliche) {
	my $default-level = $cliche.default-level // default-level;
	my $default-pattern = $cliche.default-pattern // default-pattern;
 	my $grooves = (0...^$cliche.writers.elems).list.map(-> $i { (
			get-writer($cliche.writers[$i]).make-writer(:$default-pattern),
			get-filter($cliche.filters[$i]).make-filter(:$default-level)
	) }).list;
	return $grooves.elems > 0
		?? LogP6::LoggerPure.new(:$trait, :$grooves)
		!! LogP6::LoggerMute.new;
}

sub wrap-to-sync-logger($logger) {
	given $sync-strategy {
		when 'time' {
			LoggerSyncTime.new(aggr => $logger, seconds => 60,
					get-fresh-logger => &get-logger-pure);
		}
		default {
			$logger;
		}
	}
}

sub find-cliche-for-trait($trait) {
	for @cliches.reverse -> $cliche {
		return $cliche if $trait ~~ $cliche.matcher;
	}

	die 'create default cliche for trait ' ~ $trait;
}

sub get-logger(Str:D $trait --> Logger:D) is export(:MANDATORY) {
	lock.protect({
		return $_ with %loggers{$trait};
		create-and-store-logger($trait);
		%loggers{$trait}
	});
}

sub get-logger-pure(Str:D $trait --> Logger:D) is export(:configure) {
	lock.protect({
		return $_ with %loggers-pure{$trait};
		create-and-store-logger($trait);
	});
}

sub remove-logger(Str:D $trait --> Logger) is export(:configure) {
	lock.protect({
		my $old = %loggers{$trait}:delete;
		%loggers-pure{$trait}:delete;
		return $old // Logger;
	});
}

sub create-and-store-logger($trait) {
	my $cliche = find-cliche-for-trait($trait);
	my $logger-pure = create-logger($trait, $cliche);

	%loggers{$trait} = wrap-to-sync-logger($logger-pure);
	%loggers-pure{$trait} = $logger-pure;
	(%cliches-to-loggers{$cliche.name} //= SetHash.new){$trait} = True;

	return $logger-pure;
}

END {
	with $writer-manager {
		for $writer-manager.all().values -> $writer {
			$writer.close();
		}
	}
}

initialize;