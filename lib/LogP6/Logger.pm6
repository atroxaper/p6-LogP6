use LogP6::Level;
use LogP6::Context;
use LogP6::ThreadLocal;

class LogP6::Cliche {
	has Str:D $.name is required;
	has $.matcher is required;
	has Int $.default-level;
	has Str $.default-pattern;
	has Positional $.writers;
	has Positional $.filters;

	method has(LogP6::Cliche:D: $name, Str:D $type where * ~~ any('writer', 'filter')
			--> Bool:D
	) {
		my $iter = $type eq 'writer' ?? $!writers !! $!filters;
		so $iter.grep(* eq $name);
	}

	method copy-with-new(LogP6::Cliche:D: $old, $new,
			Str:D $type where * ~~ any('writer', 'filter')
	) {
		my $new-writers = $!writers;
		my $new-filters = $!filters;
		$new-writers = $new-writers.map(-> $w { $w eq $old ?? $new !! $w }).list
				if $type eq 'writer';
		$new-filters = $new-filters.map(-> $f { $f eq $old ?? $new !! $f }).list
				if $type eq 'filter';
		self.clone(writers => $new-writers, filters => $new-filters);
	}
}

role LogP6::Logger {
	method ndc-push($obj) { ... }
	method ndc-pop() { ... }
	method ndc-clean() { ... }
	method mdc-put($key, $obj) { ... }
	method mdc-remove($key) { ... }
	method mdc-clean() { ... }
	method trace(*@args, :$x) { ... }
	method debug(*@args, :$x) { ... }
	method info(*@args, :$x) { ... }
	method warn(*@args, :$x) { ... }
	method error(*@args, :$x) { ... }
}

class LogP6::LoggerWOSync does LogP6::Logger {
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

sub get-context() {
	return LogP6::Context.get-myself;
	CATCH {
		# did not check application of the role for performance goal.
		# that will throw only one and first time for each thread
		default {
			$*THREAD does LogP6::ThreadLocal;
			return LogP6::Context.get-myself;
		}
	}
}

class LogP6::LoggerAbstractSync does LogP6::Logger {
	has LogP6::LoggerWOSync:D $.aggr is required;
	has &.get-fresh-logger is required;

	method sync($context) { ... }

	method get-sync-obj() {
		get-context.sync($!aggr.trait);
	}

	method put-sync-obj($obj) {
		get-context.sync-put($!aggr.trait, $obj);
	}

	method update-aggr() {
		say $!aggr.WHICH;
		$!aggr = &!get-fresh-logger($!aggr.trait);
		say $!aggr.WHICH;
	}

	method ndc-push($obj) { $!aggr.ndc-push($obj) }
	method ndc-pop()      { $!aggr.ndc-pop() }
	method ndc-clean()    { $!aggr.ndc-clean() }
	method mdc-put($key, $obj) { $!aggr.mdc-put($key, $obj) }
	method mdc-remove($key)    { $!aggr.mdc-remove($key) }
	method mdc-clean()         { $!aggr.mdc-clean() }
	method trace(*@args, :$x) { self.sync(get-context); $!aggr.trace(|@args, :$x)}
	method debug(*@args, :$x) { self.sync(get-context); $!aggr.debug(|@args, :$x)}
	method info(*@args, :$x)  { self.sync(get-context);  $!aggr.info(|@args, :$x)}
	method warn(*@args, :$x)  { self.sync(get-context);  $!aggr.warn(|@args, :$x)}
	method error(*@args, :$x) { self.sync(get-context); $!aggr.error(|@args, :$x)}
}

class LogP6::LoggerTimeSync is LogP6::LoggerAbstractSync {
	has Int:D $.seconds is required;

	method sync($context) {
		my DateTime $last = self.get-sync-obj // DateTime.now;
		my $now = $context.date;
		self.update-aggr if $now - $last > $!seconds;
		say $now - $last;
		self.put-sync-obj($now);
	}
}