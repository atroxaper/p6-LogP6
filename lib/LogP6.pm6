unit module LogP6;

# TODO
# (1). add support of '' (default) writers and filters (create them at start)
# (2). add START support (create default)
# 3. add STOP support (close all writers)
# (4). add EXPORT strategy (one for configuring, one for getting)
# 5. logger wrappers and sync
# 6. init from file
# 7. cliche factories
# 8. improve exceptions
# 9. improve writer format
# 10. tests tests tests
# 11. docs docs docs
# 12. add methods for logger
# 13. add 'turn off' logger (in cliche and Logger)
# 14. add support custom writer (sql or so)
# (15). add support of str format (lazy creation of msg)
# 16. improve logger log method to be more lazy

use UUID;

use LogP6::Logger;
use LogP6::Writer;
use LogP6::Filter;
use LogP6::Level;
use LogP6::ThreadLocal;

our $trace is export(:configure) = trace;
our $debug is export(:configure) = debug;
our $info  is export(:configure) = info;
our $warn  is export(:configure) = Level::warn;
our $error is export(:configure) = error;

my Lock \lock .= new;

my @cliches = [];
my $clishes-names = SetHash.new;
my %clishes-to-loggers = %();
my %loggers = %();

my Str \default-pattern = "default %s";
my Level \default-level = info;

sub initialize() {
	cliche(name => '', matcher => /.*/,
			grooves => (writer(name => ''), filter(name => '')));
}

my role GroovesPartsManager[$lock, $part-name, ::Type] {
	my %parts = %();

	method create(Str :$name, *%fields) {
		with $name {
			return $lock.protect({
				die "$part-name with name $name already exists" with %parts{$name};
				%parts{$name} = Type.new: :$name, |%fields;
			});
		} else {
			return Type.new: |%fields;
		}
	}

	method update(Str:D :$name!, *%fields) {
		$lock.protect({
			die "there is no $part-name with name $name" without %parts{$name};
			my $old = %parts{$name}:delete;
			my %new-fields = %();
			for %fields.kv -> $f-name, $f-value {
				%new-fields{$f-name} = $f-value // $old."$f-name"();
			}
			my $new = self.create(:$name, |%new-fields);
			update-loggers(find-cliche-with($name, $part-name));
			return $old;
		});
	}

	method replace(Str:D :$name!, *%fields) {
		$lock.protect({
			my $old = %parts{$name}:delete;
			my $new = self.create(:$name, |%fields);
			update-loggers(find-cliche-with($name, $part-name));
			return $old // Type;
		});
	}

	method remove(Str:D :$name!) {
		die "remove default $part-name is prohibited" if $name eq '';
		$lock.protect({
			my $old = %parts{$name}:delete;
			with $old {
				my @found := find-cliche-with($old.name, $part-name);
				for @found -> $old-cliche {
					my $new-cliche = $old-cliche
							.copy-with-new($old.name, '', $part-name);
					change-cliche($old-cliche, $new-cliche);
				}
				update-loggers(@found);
			}
			return $old // Type;
		});
	}

	method get(Str:D $name) {
		$lock.protect({ %parts{$name} // Type });
	}

	method put(Type:D $part) {
		$lock.protect({ %parts{$part.name} = $part });
	}
}

my $filter-manager =
		GroovesPartsManager[lock, 'filter', FilterConf].new;
my $writer-manager =
		GroovesPartsManager[lock, 'writer', WriterConf].new;

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
		IO::Handle :$handle
		--> WriterConf:D
) {
	$writer-manager.create(:$name, :$pattern, :$handle);
}

multi sub writer(
		Str :$name,
		Str :$pattern,
		IO::Handle :$handle,
		Bool:D :$create! where *.so
		--> WriterConf:D
) {
	$writer-manager.create(:$name, :$pattern, :$handle);
}

multi sub writer(
		Str:D :$name!,
		Str :$pattern,
		IO::Handle :$handle,
		Bool:D :$update! where *.so
		--> WriterConf:D
) {
	$writer-manager.update(:$name, :$pattern, :$handle);
}

multi sub writer(
		Str:D :$name!,
		Str :$pattern,
		IO::Handle :$handle,
		Bool:D :$replace! where *.so
		--> WriterConf
) {
	$writer-manager.replace(:$name, :$pattern, :$handle);
}

multi sub writer(Str:D :$name!, Bool:D :$remove! where *.so --> WriterConf) {
	$writer-manager.remove(:$name);
}

proto cliche(| --> Cliche) is export(:configure) { * }

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	Level :$default-level, Str :$default-pattern, Positional :$grooves
	--> Cliche:D
) {
	lock.protect({
		die "cliche with name $name already exists" if $clishes-names{$name};
		my $grvs = ($grooves // (),)>>.List.flat;
		die "grooves must have even amount of elements" unless $grvs %% 2;

		check-part(WriterConf, 'writer', $writer-manager, $_) for $grvs[0,2...^*];
		check-part(FilterConf, 'filter', $filter-manager, $_) for $grvs[1,3...^*];

		my $writers-names = $grvs[0,2...^*]>>.&get-part-name($writer-manager).List;
		my $filters-names = $grvs[1,3...^*]>>.&get-part-name($filter-manager).List;

		$clishes-names<$name> = True;
		my $cliche = Cliche.new(:$name, :$default-level, :$default-pattern,
				:$matcher, writers => $writers-names, filters => $filters-names);
		@cliches.push: $cliche;
		$cliche;
	});
}

sub get-part-name($part, $type-manager) {
	return $part if $part ~~ Str;
	return $part.name with $part.name;
	my $clone = $part.clone(name => UUID.new.Str);
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

sub find-cliche-with(Str:D $name!,
		Str:D $type where * ~~ any('writer', 'filter') --> List:D
) {
	@cliches.grep(*.has($name, $type)).list;
}

sub update-loggers(Positional:D $cliches) {
	for |$cliches -> $cliche {
		for |%clishes-to-loggers{$cliche.name} -> $trait {
			next unless $trait;
			%loggers{$trait} = create-logger($trait, $cliche);
		}
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
	my $level = $cliche.default-level // default-level;
	my $pattern = $cliche.default-pattern // default-pattern;
 	my $grooves = (0...^$cliche.writers.elems).list.map(-> $i { (
			Writer.new(get-writer($cliche.writers[$i]), $pattern),
			Filter.new(get-filter($cliche.filters[$i]), $level)
	) }).list;
	Logger.new(:$trait, :$grooves);
}

sub find-cliche-for-trait($trait) {
	for @cliches.reverse -> $cliche {
		return $cliche if $trait ~~ $cliche.matcher;
	}

	die 'create default cliche';
}

sub get-logger(Str:D $trait --> Logger:D) is export(:MANDATORY) {
	lock.protect({
		return $_ with %loggers{$trait};

		my $cliche = find-cliche-for-trait($trait);
		my $logger = create-logger($trait, $cliche);

		%loggers{$trait} = $logger;
		(%clishes-to-loggers{$cliche.name} //= []).push: $trait;

		return $logger;
	});
}

initialize;