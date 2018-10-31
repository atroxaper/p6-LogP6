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

role LogP6::LoggerRole {
	method info(Str:D $msg) { ... }
	method debug(Str:D $msg) { ... }
	method ndc-push($obj) { ... }
	method ndc-pop() { ... }
	method ndc-clean() { ... }
}

class LogP6::Logger does LogP6::LoggerRole {
	has Str:D $.trait is required;
	has List:D $.grooves is required;

	method info(*@args, :$x) {
		self!log(info, @args, :$x);
	}

	method debug(*@args, :$x) {
		self!log(debug, @args, :$x);
	}

	method !log($level, @args, :$x) {
		my LogP6::Context $context = self!get-context();
		$context.trait-set($!trait);
		$context.x-set($x);
		my $msg;
		for @$!grooves -> $groove {
			my ($writer, $filter) = $groove;
			$context.reset($msg //= msg(@args), $level);

			if $filter.do-before($context) {
				$writer.write($context);
				$filter.do-after($context);
			}
		}
		$context.clean();
	}

	sub msg(@args) {
		@args.elems < 2 ?? @args[0] !! sprintf(@args[0], |@args[1..*]);
	}

	method !get-context() {
		return LogP6::Context.get-myself;
		CATCH {
			default {
				$*THREAD does LogP6::ThreadLocal;
				return LogP6::Context.get-myself;
			}
		}
	}

	method ndc-push($obj) {
		self!get-context.ndc-push: $obj;
	}

	method ndc-pop() {
		self!get-context.ndc-pop;
	}

	method ndc-clean() {
		self!get-context.ndc-clean;
	}
}