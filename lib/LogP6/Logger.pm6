use LogP6::Level;
use LogP6::Context;
use LogP6::ThreadLocal;

role LogP6::Logger {
	method trait() { ... }
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

sub get-context() is export {
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