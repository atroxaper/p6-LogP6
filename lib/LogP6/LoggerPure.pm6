use LogP6::Level;
use LogP6::Logger;
use LogP6::FilterConf::Std;
use LogP6::Exceptions;

class LogP6::LoggerPure does LogP6::Logger {
	has Str:D $.trait is required;
	has List:D $.grooves is required;
	has LogP6::Level $!reactive-level;
	has $!if-logger;

	submethod TWEAK() {
		die 'pure logger with empty grooves: ' ~ $!trait if $!grooves.elems < 1;
		# use minimum level of all grooves filters reactive-level
		$!reactive-level =
				@$!grooves.map(-> $g {$g[1].reactive-level // LogP6::Level::trace}).min;
		$!if-logger = LogP6::Level.enums
			.sort(*.value)
			.map(-> $level {
				$level.value >= $!reactive-level
					?? LogP6::IfLogger.new(:level($level.value), :log(self))
					!! Any
			}).List;
	}

	method trait() {
		$!trait;
	}

	method ndc-push($obj) {
		CATCH { default { logp6-error($_) } }
		get-context.ndc-push: $obj;
	}

	method ndc-pop() {
		try {
			CATCH { default { logp6-error($_) } }
			return get-context.ndc-pop;
		}
	}

	method ndc-clean() {
		CATCH { default { logp6-error($_) } }
		get-context.ndc-clean;
	}

	method mdc-put($key, $obj) {
		CATCH { default { logp6-error($_) } }
		get-context.mdc-put: $key, $obj;
	}

	method mdc-remove($key) {
		CATCH { default { logp6-error($_) } }
		get-context.mdc-remove: $key;
	}

	method mdc-clean() {
		CATCH { default { logp6-error($_) } }
		get-context.mdc-clean;
	}

	method dc-copy() {
		CATCH { default { logp6-error($_) } }
		get-context.dc-get;
	}

	method dc-restore($dc) {
		CATCH { default { logp6-error($_) } }
		get-context.dc-restore($dc);
	}

	method level($level, *@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > $level;
		self!log($level, msg(@args), $x);
	}

	method levelf($level, *@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > $level;
		self!log($level, msgf(@args), $x);
	}

	method trace(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::trace;
		self!log(LogP6::Level::trace, msg(@args), $x);
	}

	method tracef(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::trace;
		self!log(LogP6::Level::trace, msgf(@args), $x);
	}

	method debug(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::debug;
		self!log(LogP6::Level::debug, msg(@args), $x);
	}

	method debugf(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::debug;
		self!log(LogP6::Level::debug, msgf(@args), $x);
	}

	method info(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::info;
		self!log(LogP6::Level::info, msg(@args), $x);
	}

	method infof(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::info;
		self!log(LogP6::Level::info, msgf(@args), $x);
	}

	method warn(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::warn;
		self!log(LogP6::Level::warn, msg(@args), $x);
	}

	method warnf(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::warn;
		self!log(LogP6::Level::warn, msgf(@args), $x);
	}

	method error(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::error;
		self!log(LogP6::Level::error, msg(@args), $x);
	}

	method errorf(*@args, :$x) {
		CATCH { default { logp6-error($_) } }
		return if $!reactive-level > LogP6::Level::error;
		self!log(LogP6::Level::error, msgf(@args), $x);
	}

	submethod !log($level, $msg, $x) {
		my LogP6::Context $context = get-context();
		$context.trait-set($!trait);
		my ($writer, $filter);
		for @$!grooves -> $groove {
			($writer, $filter) = $groove;
			$context.reset($msg, $level, $x);

			if $filter.do-before($context) {
				$writer.write($context);
				$filter.do-after($context);
			}
		}
		$context.clean();
	}

	sub msgf(@args) {
		@args.elems > 1
			?? sprintf(@args[0], |@args[1..*])
			!! @args.elems == 1
				?? @args[0]
				!! '';
	}

	sub msg(@args) {
		@args.elems == 1
			?? @args[0]
			!! @args.elems > 1
				?? @args.join('')
				!! '';
	}

	method trace-on() { $!if-logger[LogP6::Level::trace-1] }
	method debug-on() { $!if-logger[LogP6::Level::debug-1] }
	method info-on()  { $!if-logger[LogP6::Level::info -1] }
	method warn-on()  { $!if-logger[LogP6::Level::warn -1] }
	method error-on() { $!if-logger[LogP6::Level::error-1] }
	method level-on($level) { $!if-logger[$level-1] }
}

class LogP6::LoggerMute does LogP6::Logger {
	has Str:D $.trait is required;
	method trait() { $!trait }
	method ndc-push($obj) {}
	method ndc-pop() {}
	method ndc-clean() {}
	method mdc-put($key, $obj) {}
	method mdc-remove($key) {}
	method mdc-clean() {}
	method dc-copy() { Nil }
	method dc-restore($dc) {}
	method level($level, *@args, :$x) { get-context().clean }
	method levelf($level, *@args, :$x) { get-context().clean }
	method trace(*@args, :$x) { get-context().clean }
	method tracef(*@args, :$x) { get-context().clean }
	method debug(*@args, :$x) { get-context().clean }
	method debugf(*@args, :$x) { get-context().clean }
	method info(*@args, :$x) { get-context().clean }
	method infof(*@args, :$x) { get-context().clean }
	method error(*@args, :$x) { get-context().clean }
	method errorf(*@args, :$x) { get-context().clean }
	method warn(*@args, :$x) { get-context().clean }
	method warnf(*@args, :$x) { get-context().clean }
	method trace-on() { get-context().clean; Any }
	method debug-on() { get-context().clean; Any }
	method info-on()  { get-context().clean; Any }
	method warn-on()  { get-context().clean; Any }
	method error-on() { get-context().clean; Any }
	method level-on($level) { get-context().clean; Any }
}
