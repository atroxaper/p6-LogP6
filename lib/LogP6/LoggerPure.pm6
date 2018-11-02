use LogP6::Level;
use LogP6::Logger;

class LogP6::LoggerPure does LogP6::Logger {
	has Str:D $.trait is required;
	has List:D $.grooves is required;
	has $!first-filter;

	submethod TWEAK() {
		# save the first filter separately
		$!first-filter = $!grooves[0][1];
	}

	method ndc-push($obj) {
		get-context.ndc-push: $obj, $!trait;
	}

	method ndc-pop() {
		get-context.ndc-pop: $!trait;
	}

	method ndc-clean() {
		get-context.ndc-clean: $!trait;
	}

	method mdc-put($key, $obj) {
		get-context.mdc-put: $key, $obj, $!trait;
	}

	method mdc-remove($key) {
		get-context.mdc-remove: $key, $!trait;
	}

	method mdc-clean() {
		get-context.mdc-clean; $!trait;
	}

	method trace(*@args, :$x) {
		return if !$!first-filter.reactive-check(trace);
		self!log(trace, @args, :$x);
	}

	method debug(*@args, :$x) {
		return if !$!first-filter.reactive-check(debug);
		self!log(debug, @args, :$x);
	}

	method info(*@args, :$x) {
		return if !$!first-filter.reactive-check(info);
		self!log(info, @args, :$x);
	}

	method warn(*@args, :$x) {
		return if !$!first-filter.reactive-check(warn);
		self!log(warn, @args, :$x);
	}

	method error(*@args, :$x) {
		return if !$!first-filter.reactive-check(error);
		self!log(error, @args, :$x);
	}

	submethod !log($level, @args, :$x) {
		my LogP6::Context $context = get-context();
		$context.trait-set($!trait);
		$context.x-set($x);
		my $msg = msg(@args);
		my ($writer, $filter);
		for @$!grooves -> $groove {
			($writer, $filter) = $groove;
			$context.reset($msg, $level);

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
