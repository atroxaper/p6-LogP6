use LogP6::Level;
use LogP6::Logger;
use LogP6::Filter;

class LogP6::LoggerPure does LogP6::Logger {
	has Str:D $.trait is required;
	has List:D $.grooves is required;
	has $!reactive-filter;

	submethod TWEAK() {
		die 'pure logger with empty grooves: ' ~ $!trait if $!grooves.elems < 1;
		# find minimum level of all grooves filters
		# if any filter has no first-level-check then use trace as minimum level
		my $min-level = error;
		for @$!grooves -> $groove {
			$min-level = min($groove[1].level, $min-level);
			unless $groove[1].first-level-check {
				$min-level = trace;
				last;
			}
		}
		# filter for decision wo we need to go to grooves or can ignore log
		$!reactive-filter = LogP6::FilterConfStd
			.new(:level($min-level), :first-level-check).make-filter();
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
		return if !$!reactive-filter.reactive-check(trace);
		self!log(trace, @args, :$x);
	}

	method debug(*@args, :$x) {
		return if !$!reactive-filter.reactive-check(debug);
		self!log(debug, @args, :$x);
	}

	method info(*@args, :$x) {
		return if !$!reactive-filter.reactive-check(info);
		self!log(info, @args, :$x);
	}

	method warn(*@args, :$x) {
		return if !$!reactive-filter.reactive-check(warn);
		self!log(warn, @args, :$x);
	}

	method error(*@args, :$x) {
		return if !$!reactive-filter.reactive-check(error);
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

class LogP6::LoggerMute does LogP6::Logger {
	method ndc-push($obj) {}
	method ndc-pop() {}
	method ndc-clean() {}
	method mdc-put($key, $obj) {}
	method mdc-remove($key) {}
	method mdc-clean() {}
	method trace(*@args, :$x) {}
	method debug(*@args, :$x) {}
	method info(*@args, :$x) {}
	method error(*@args, :$x) {}
	method warn(*@args, :$x) {}
}
