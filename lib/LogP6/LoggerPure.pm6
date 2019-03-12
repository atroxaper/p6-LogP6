use LogP6::Level;
use LogP6::Logger;
use LogP6::FilterConf::Std;

class LogP6::LoggerPure does LogP6::Logger {
	has Str:D $.trait is required;
	has List:D $.grooves is required;
	has LogP6::Level $!reactive-level;

	submethod TWEAK() {
		die 'pure logger with empty grooves: ' ~ $!trait if $!grooves.elems < 1;
		# use minimum level of all grooves filters reactive-level
		$!reactive-level =
				@$!grooves.map(-> $g {$g[1].reactive-level // LogP6::Level::trace}).min;
	}

	method ndc-push($obj) {
		get-context.ndc-push: $obj;
	}

	method ndc-pop() {
		get-context.ndc-pop;
	}

	method ndc-clean() {
		get-context.ndc-clean;
	}

	method mdc-put($key, $obj) {
		get-context.mdc-put: $key, $obj;
	}

	method mdc-remove($key) {
		get-context.mdc-remove: $key;
	}

	method mdc-clean() {
		get-context.mdc-clean;
	}

	method trace(*@args, :$x) {
		return if $!reactive-level > LogP6::Level::trace;
		self!log(LogP6::Level::trace, @args, :$x);
	}

	method debug(*@args, :$x) {
		return if $!reactive-level > LogP6::Level::debug;
		self!log(LogP6::Level::debug, @args, :$x);
	}

	method info(*@args, :$x) {
		return if $!reactive-level > LogP6::Level::info;
		self!log(LogP6::Level::info, @args, :$x);
	}

	method warn(*@args, :$x) {
		return if $!reactive-level > LogP6::Level::warn;
		self!log(LogP6::Level::warn, @args, :$x);
	}

	method error(*@args, :$x) {
		return if $!reactive-level > LogP6::Level::error;
		self!log(LogP6::Level::error, @args, :$x);
	}

	submethod !log($level, @args, :$x) {
		my LogP6::Context $context = get-context();
		$context.trait-set($!trait);
		my $msg = msg(@args);
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

	sub msg(@args) {
		@args.elems < 2 ?? @args[0] // '' !! sprintf(@args[0], |@args[1..*]);
	}
}

class LogP6::LoggerMute does LogP6::Logger {
	has Str:D $.trait is required;
	method ndc-push($obj) {}
	method ndc-pop() {}
	method ndc-clean() {}
	method mdc-put($key, $obj) {}
	method mdc-remove($key) {}
	method mdc-clean() {}
	method trace(*@args, :$x) { get-context().clean }
	method debug(*@args, :$x) { get-context().clean }
	method info(*@args, :$x) { get-context().clean }
	method error(*@args, :$x) { get-context().clean }
	method warn(*@args, :$x) { get-context().clean }
}
