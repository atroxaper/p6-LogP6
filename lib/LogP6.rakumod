unit module LogP6;

use UUID;

use LogP6::Logger;
use LogP6::LoggerPure;
use LogP6::Wrapper;
use LogP6::Wrapper::Transparent;

use LogP6::Filter;
use LogP6::FilterConf::Std;

use LogP6::Writer;
use LogP6::WriterConf::Std;
use LogP6::WriterConf::Pattern;

use LogP6::Cliche;

use LogP6::Level;
use LogP6::ThreadLocal;

use LogP6::ConfigFile;
use LogP6::LogGetter;

use LogP6::Exceptions;

our $trace is export(:configure) = Level::trace;
our $debug is export(:configure) = Level::debug;
our $info  is export(:configure) = Level::info;
our $warn  is export(:configure) = Level::warn;
our $error is export(:configure) = Level::error;

my Lock $lock .= new;
my atomicint $initialized = 0;

my LogP6::ConfigFile $config-file;

my @cliches;
my $cliches-names;
my %cliches-to-traits;
my $loggers-pure = %();
my $loggers = $();

my Str $default-pattern;
my Bool $default-auto-exceptions;
my IO::Handle $default-handle;
my Str $default-x-pattern;

my Level $default-level;
my Bool $default-first-level-check;

my LogP6::Wrapper $default-wrapper;

my $f-manager;
my $w-manager;

my role GroovesPartsManager[$lock, $part-name, ::Type, ::NilType] { ... }

#| Have to call it from all (mostly) export methods.
#| It will initialize loggers in user script context instead of on precomp
sub try-initialize() {
	my $already = ⚛$initialized;
	return if $already > 0;
	$lock.protect({
		$already = ⚛$initialized;
		return if $already > 0;
		init-from-file(default-config-path());
	});
}

sub init-from-file($config-path) is export(:configure) {
	$lock.protect({
		my $prev-initialized = ⚛$initialized;
		$initialized ⚛= 1;

		init-getter(
			get-wrap => sub ($t) { get-logger($t) },
			get-pure => sub ($t) { get-logger-pure($t) });

		without $config-path {
			wipe-log-config();
			return;
		}

		unless $config-path.trim.Bool {
			logp6-error('log-p6 config-path is blank');
			wipe-log-config();
			return;
		}
		if !$config-path.IO.e {
			logp6-error("log-p6 config '$config-path' is not exist");
			wipe-log-config();
			return;
		}

		my $config;
		try {
			$config-file //= LogP6::ConfigFile.new;
			$config = $config-file.parse-config($config-path);
			CATCH { default {
				logp6-error($_);
				wipe-log-config() if $prev-initialized == 0;
				return;
			}}
		}
		wipe-log-config();
		set-default-pattern($_) with $config.default-pattern;
		set-default-auto-exceptions($_) with $config.default-auto-exceptions;
		set-default-handle($_) with $config.default-handle;
		set-default-x-pattern($_) with $config.default-x-pattern;
		set-default-level($_) with $config.default-level;
		set-default-first-level-check($_) with $config.default-first-level-check;
		set-default-wrapper($_) with $config.default-wrapper;
		writer($_) for $config.writers;
		filter($_) for $config.filters;
		cliche($_) for $config.cliches;
		CATCH { default { logp6-error($_); .resume } }
	});
}

sub wipe-log-config() is export(:configure) {
	# not need try-initialize()
	clean-all-settings();
	create-default-cliche();
}

sub create-default-cliche() {
	cliche(name => '', matcher => /.*/,
			grooves => (writer(name => ''), filter(name => '')));
}

sub clean-all-settings() {
	@cliches = [];
	$cliches-names = SetHash.new;
	%cliches-to-traits = %();
	$loggers-pure = %();
	$loggers = %();

	$default-pattern = '[%date{$hh:$mm:$ss}][%level] %msg';
	die "wrong default pattern <$($default-pattern)>"
		unless Grammar.parse($default-pattern);
	$default-auto-exceptions = True;
	$default-handle = $*OUT;
	$default-x-pattern = '%x{ Exception $name: $msg' ~ $?NL ~ '$trace}';

	$default-level = Level::error;
	$default-first-level-check = True;

	$default-wrapper = LogP6::Wrapper::Transparent::Wrapper.new;

	$f-manager = GroovesPartsManager[
			$lock, 'filter', LogP6::FilterConf::Std, LogP6::FilterConf].new;
	$w-manager = GroovesPartsManager[
			$lock, 'writer', LogP6::WriterConf::Std, LogP6::WriterConf].new;
}

sub set-default-pattern(Str:D $pattern) is export(:configure) {
	try-initialize();
	die "wrong default pattern <$($pattern)>" unless Grammar.parse($pattern);
	$default-pattern = $pattern;
	update-loggers();
}

sub set-default-auto-exceptions(Bool:D $auto-exceptions)
	is export(:configure)
{
	try-initialize();
	$default-auto-exceptions = $auto-exceptions;
	update-loggers();
}

sub set-default-handle(IO::Handle:D $handle) is export(:configure)
{
	try-initialize();
	$default-handle = $handle;
	update-loggers();
}

sub set-default-x-pattern(Str:D $x-pattern) is export(:configure)
{
	try-initialize();
	$default-x-pattern = $x-pattern;
	update-loggers();
}

sub set-default-level(LogP6::Level:D $level) is export(:configure) {
	try-initialize();
	$default-level = $level;
	update-loggers();
}

sub set-default-first-level-check(Bool:D $first-level-check)
	is export(:configure)
{
	try-initialize();
	$default-first-level-check = $first-level-check;
	update-loggers();
}

sub set-default-wrapper(LogP6::Wrapper $factory) is export(:configure) {
	try-initialize();
	$default-wrapper = $factory // LogP6::Wrapper::Transparent::Wrapper.new;
	update-loggers();
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

sub get-filter(Str:D $name --> LogP6::FilterConf) is export(:configure) {
	try-initialize();
	$f-manager.get($name);
}

sub level(Level:D $level --> LogP6::FilterConf:D) is export(:configure) {
	try-initialize();
	$f-manager.create(:$level);
}

proto filter(| --> LogP6::FilterConf) is export(:configure) { * }

multi sub filter(
		Str :$name,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check
		--> LogP6::FilterConf:D
) {
	try-initialize();
	$f-manager.create(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
		Str :$name,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check,
		Bool:D :$create! where *.so
		--> LogP6::FilterConf:D
) {
	try-initialize();
	$f-manager.create(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
	LogP6::FilterConf:D $filter,
	--> LogP6::FilterConf:D
) {
	try-initialize();
	$f-manager.create($filter);
}

multi sub filter(
	LogP6::FilterConf:D $filter,
	Bool:D :$create! where *.so
	--> LogP6::FilterConf:D
) {
	try-initialize();
	$f-manager.create($filter);
}

multi sub filter(
		Str:D :$name!,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check,
		Bool:D :$update! where *.so
		--> LogP6::FilterConf:D
) {
		try-initialize();
	$f-manager.update(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
		Str:D :$name!,
		Level :$level,
		Bool :$first-level-check,
		List :$before-check,
		List :$after-check,
		Bool:D :$replace! where *.so
		--> LogP6::FilterConf
) {
	try-initialize();
	$f-manager.replace(:$name, :$level, :$first-level-check,
			:$before-check, :$after-check);
}

multi sub filter(
	LogP6::FilterConf:D $filter,
	Bool:D :$replace! where *.so
	--> LogP6::FilterConf:D
) {
	try-initialize();
	$f-manager.replace($filter);
}

multi sub filter(Str:D :$name!, Bool:D :$remove! where *.so
	--> LogP6::FilterConf
) {
	try-initialize();
	$f-manager.remove(:$name);
}

sub get-writer(Str:D $name --> LogP6::WriterConf) is export(:configure) {
	try-initialize();
	$w-manager.get($name);
}

proto writer(| --> LogP6::WriterConf) is export(:configure) { * }

multi sub writer(
		Str :$name,
		Str :$pattern,
		Bool :$auto-exceptions,
		IO::Handle :$handle
		--> WriterConf:D
) {
	try-initialize();
	$w-manager.create(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
		Str :$name,
		Str :$pattern,
		Bool :$auto-exceptions,
		IO::Handle :$handle,
		Bool:D :$create! where *.so
		--> LogP6::WriterConf:D
) {
	try-initialize();
	$w-manager.create(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
		WriterConf:D $writer,
		--> WriterConf:D
) {
	try-initialize();
	$w-manager.create($writer);
}

multi sub writer(
		LogP6::WriterConf:D $writer,
		Bool:D :$create! where *.so
		--> LogP6::WriterConf:D
) {
	try-initialize();
	$w-manager.create($writer);
}

multi sub writer(
		Str:D :$name!,
		Str :$pattern,
		IO::Handle :$handle,
		Bool :$auto-exceptions,
		Bool:D :$update! where *.so
		--> LogP6::WriterConf:D
) {
	try-initialize();
	$w-manager.update(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
		Str:D :$name!,
		Str :$pattern,
		IO::Handle :$handle,
		Bool :$auto-exceptions,
		Bool:D :$replace! where *.so
		--> LogP6::WriterConf
) {
	try-initialize();
	$w-manager.replace(:$name, :$pattern, :$auto-exceptions, :$handle);
}

multi sub writer(
	LogP6::WriterConf:D $writer,
	Bool:D :$replace! where *.so
	--> LogP6::WriterConf:D
) {
	try-initialize();
	$w-manager.replace($writer);
}

multi sub writer(Str:D :$name!, Bool:D :$remove! where *.so
	--> LogP6::WriterConf
) {
	try-initialize();
	$w-manager.remove(:$name);
}

sub get-cliche(Str:D $name --> LogP6::Cliche) is export(:configure) {
	try-initialize();
	$lock.protect({
		@cliches.grep(*.name eq $name).first // LogP6::Cliche;
	});
}

proto cliche(| --> LogP6::Cliche) is export(:configure) { * }

multi sub cliche(LogP6::Cliche:D $cliche --> LogP6::Cliche:D) {
	try-initialize();
	cliche(:name($cliche.name), :matcher($cliche.matcher),
			:wrapper($cliche.wrapper), :grooves($cliche.grooves),
			:default-pattern($cliche.default-pattern),
			:default-auto-exceptions($cliche.default-auto-exceptions),
			:default-handle($cliche.default-handle),
			:default-x-pattern($cliche.default-x-pattern),
			:default-level($cliche.default-level),
			:default-first-level-check($cliche.default-first-level-check), :create);
}

multi sub cliche(LogP6::Cliche:D $cliche, :$create! where *.so
	--> LogP6::Cliche:D
) {
	try-initialize();
	cliche(:name($cliche.name), :matcher($cliche.matcher),
			:wrapper($cliche.wrapper), :grooves($cliche.grooves),
			:default-pattern($cliche.default-pattern),
			:default-auto-exceptions($cliche.default-auto-exceptions),
			:default-handle($cliche.default-handle),
			:default-x-pattern($cliche.default-x-pattern),
			:default-level($cliche.default-level),
			:default-first-level-check($cliche.default-first-level-check), :create);
}

multi sub cliche(LogP6::Cliche:D $cliche, :$replace! where *.so
	--> LogP6::Cliche:D
) {
	try-initialize();
	cliche(:name($cliche.name), :matcher($cliche.matcher),
			:wrapper($cliche.wrapper), :grooves($cliche.grooves),
			:default-pattern($cliche.default-pattern),
			:default-auto-exceptions($cliche.default-auto-exceptions),
			:default-handle($cliche.default-handle),
			:default-x-pattern($cliche.default-x-pattern),
			:default-level($cliche.default-level),
			:default-first-level-check($cliche.default-first-level-check), :replace);
}

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	LogP6::Wrapper :$wrapper, Positional :$grooves,
	Str :$default-pattern, Bool :$default-auto-exceptions,
	IO::Handle :$default-handle, Str :$default-x-pattern,
	Level :$default-level, Bool :$default-first-level-check
	--> LogP6::Cliche:D
) {
	try-initialize();
	cliche(:$name, :$matcher, :$wrapper, :$grooves, :$default-pattern,
			:$default-auto-exceptions, :$default-handle, :$default-x-pattern,
			:$default-level, :$default-first-level-check, :create);
}

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	LogP6::Wrapper :$wrapper, Positional :$grooves,
	Str :$default-pattern, Bool :$default-auto-exceptions,
	IO::Handle :$default-handle, Str :$default-x-pattern,
	Level :$default-level, Bool :$default-first-level-check,
	:$create! where *.so --> LogP6::Cliche:D
) {
	try-initialize();
	$lock.protect({
		die "cliche with name $name already exists" if $cliches-names{$name};
		my $cliche = create-cliche(:$name, :$matcher, :$wrapper, :$grooves,
				:$default-pattern, :$default-auto-exceptions, :$default-handle,
				:$default-x-pattern, :$default-level, :$default-first-level-check);
		$cliches-names{$name} = True;
		@cliches.push: $cliche;
		update-loggers;
		$cliche;
	});
}

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	LogP6::Wrapper :$wrapper, Positional :$grooves,
	Str :$default-pattern, Bool :$default-auto-exceptions,
	IO::Handle :$default-handle, Str :$default-x-pattern,
	Level :$default-level, Bool :$default-first-level-check,
	:$replace! where *.so --> LogP6::Cliche
) {
	try-initialize();
	$lock.protect({
		my $new = create-cliche(:$name, :$matcher, :$wrapper, :$grooves,
				:$default-pattern, :$default-auto-exceptions, :$default-handle,
				:$default-x-pattern, :$default-level, :$default-first-level-check);
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
	try-initialize();
	die "remove default cliche is prohibited" if $name eq '';
	$lock.protect({
		return LogP6::Cliche without $cliches-names{$name};
		my $old = @cliches.grep(*.name eq $name).first // LogP6::Cliche;
		@cliches = @cliches.grep(*.name ne $name).Array;
		$cliches-names{$name} = False;
		update-loggers;
		$old;
	});
}

sub create-cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	LogP6::Wrapper :$wrapper, Positional :$grooves,
	Str :$default-pattern, Bool :$default-auto-exceptions,
	IO::Handle :$default-handle, Str :$default-x-pattern,
	Level :$default-level, Bool :$default-first-level-check
) {
	die "wrong default pattern <$default-pattern>"
			unless check-pattern($default-pattern);
	my $grvs = ($grooves // (),)>>.List.flat;
	die "grooves must have even amount of elements" unless $grvs %% 2;

	check-part(LogP6::WriterConf, 'writer', $w-manager, $_) for $grvs[0,2...^*];
	check-part(LogP6::FilterConf, 'filter', $f-manager, $_) for $grvs[1,3...^*];
	self-check-part($_) for |$grvs;

	my $writers-names = $grvs[0,2...^*]>>.&get-part-name($w-manager).List;
	my $filters-names = $grvs[1,3...^*]>>.&get-part-name($f-manager).List;

	LogP6::Cliche.new(:$name, :$matcher, :$wrapper, writers => $writers-names,
			filters => $filters-names, :$grooves, :$default-pattern,
			:$default-auto-exceptions, :$default-handle, :$default-x-pattern,
			:$default-level, :$default-first-level-check);
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
	@cliches.grep(*.has($name, $type)).List;
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
 	my $grooves = (0...^$cliche.writers.elems).List.map(-> $i { (
			get-writer($cliche.writers[$i]).make-writer(|writer-defaults($cliche)),
			get-filter($cliche.filters[$i]).make-filter(|filter-defaults($cliche))
	) }).List;
	return $grooves.elems > 0
		?? LogP6::LoggerPure.new(:$trait, :$grooves)
		!! LogP6::LoggerMute.new(:$trait);
}

sub writer-defaults($cliche) {
	return %(
		default-pattern => $cliche.default-pattern // $default-pattern,
		default-auto-exceptions =>
			$cliche.default-auto-exceptions // $default-auto-exceptions,
		default-handle => $cliche.default-handle // $default-handle,
		default-x-pattern => $cliche.default-x-pattern // $default-x-pattern
	);
}

sub filter-defaults($cliche) {
	return %(
		default-level => $cliche.default-level // $default-level,
		default-first-level-check =>
				$cliche.default-first-level-check // $default-first-level-check
	);
}

sub wrap-logger($logger, $cliche) {
	($cliche.wrapper // $default-wrapper).wrap($logger);
}

sub find-cliche-for-trait($trait) {
	for @cliches.reverse -> $cliche {
		return $cliche if $trait ~~ $cliche.matcher;
	}

	die 'create default cliche for trait ' ~ $trait;
}

sub get-logger(Str:D $trait --> Logger:D) is export(:MANDATORY) {
	return $_ with atomic-fetch($loggers){$trait};

	$lock.protect({
		try-initialize();
		return find-or-create-and-store-logger($trait);
	});
	CATCH { default { logp6-error($_); return LogP6::LoggerMute.new(:$trait) } }
}

sub get-logger-pure(Str:D $trait --> Logger:D) is export(:configure) {
	return $_ with atomic-fetch($loggers-pure){$trait};

	$lock.protect({
		try-initialize();
		return find-or-create-and-store-logger-pure($trait);
	});
	CATCH { default { logp6-error($_); return LogP6::LoggerMute.new(:$trait) } }
}

sub remove-logger(Str:D $trait --> Logger) is export(:configure) {
	try-initialize();
	$lock.protect({
		my %logs = atomic-fetch($loggers).clone;
		my %logs-pure = atomic-fetch($loggers-pure).clone;

		my $old = %logs{$trait}:delete;
		%logs-pure{$trait}:delete;

		atomic-assign($loggers, %logs);
		atomic-assign($loggers-pure, %logs-pure);

		return $old // Logger;
	});
}

multi sub update-loggers(Positional:D $cliches) {
	for |$cliches -> $cliche {
		my %copy = %cliches-to-traits{$cliche.name} // SetHash.new;
		%cliches-to-traits{$cliche.name} = SetHash.new;
		for %copy.keys -> $trait {
			logger-map-del($trait);
			logger-pure-map-del($trait);
			find-or-create-and-store-logger($trait);
		}
	}
}

multi sub update-loggers() {
	%cliches-to-traits = %();
	logger-map-clean();
	my @traits := logger-pure-map-clean();
	for @traits -> $trait {
		find-or-create-and-store-logger($trait);
	}
}

sub find-or-create-and-store-logger-pure($trait) {
	return $_ with atomic-fetch($loggers-pure){$trait};
	my $cliche = find-cliche-for-trait($trait);
	create-and-store-loggers($trait, $cliche, :pure);
}

sub find-or-create-and-store-logger($trait) {
	return $_ with atomic-fetch($loggers){$trait};
	my $cliche = find-cliche-for-trait($trait);
	create-and-store-loggers($trait, $cliche, :!pure);
}

sub create-and-store-loggers($trait, $cliche, :$pure) {
	my $logger-pure = create-logger($trait, $cliche);
	my $logger = wrap-logger($logger-pure, $cliche);
	logger-map-put($trait, $logger);
	logger-pure-map-put($trait, $logger-pure);
	(%cliches-to-traits{$cliche.name} //= SetHash.new){$trait} = True;

	return $pure ?? $logger-pure !! $logger;
}

sub logger-pure-map-put($trait, $logger-pure) {
	my %new-loggers-pure = atomic-fetch($loggers-pure).clone;
	%new-loggers-pure{$trait} = $logger-pure;
	atomic-assign($loggers-pure, %new-loggers-pure);
}

sub logger-map-put($trait, $logger) {
	my %new-loggers = atomic-fetch($loggers).clone;
	%new-loggers{$trait} = $logger;
	atomic-assign($loggers, %new-loggers);
}

sub logger-pure-map-del($trait) {
	my %new-loggers-pure = atomic-fetch($loggers-pure).clone;
	%new-loggers-pure{$trait}:delete;
	atomic-assign($loggers-pure, %new-loggers-pure);
}

sub logger-map-del($trait) {
	my %new-loggers = atomic-fetch($loggers).clone;
	%new-loggers{$trait}:delete;
	atomic-assign($loggers, %new-loggers);
}

sub logger-pure-map-clean() {
	my $keys = atomic-fetch($loggers-pure).keys.List;
	atomic-assign($loggers-pure, %());
	return $keys;
}

sub logger-map-clean() {
	my $keys = atomic-fetch($loggers).keys.List;
	atomic-assign($loggers, %());
	return $keys;
}

END {
	with $w-manager {
		for $w-manager.all().values -> $writer {
			$writer.close();
		}
	}
}