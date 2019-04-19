use LogP6::Level;
use LogP6::Context;
use LogP6::ThreadLocal;

#| Logger role.
role LogP6::Logger {
	#| Gets logger trait
	method trait() { ... }
	#| Push object to NDC
	method ndc-push($obj) { ... }
	#| Pop last pushed value from NDC
	method ndc-pop() { ... }
	#| Cleans NDC
	method ndc-clean() { ... }
	#| Puts object to MDC with specified key
	method mdc-put($key, $obj) { ... }
	#| Removes object from MDC for specified key
	method mdc-remove($key) { ... }
	#| Cleans MDC
	method mdc-clean() { ... }
	#| Get copy of NDC and MDC
	method dc-copy() { ... }
	#| Restore values of NDC and MDC from its copy
	method dc-restore($dc) { ... }
	#|[Writes log with trace importance level.
	#| @args - data for logging. If the array has more then one element then the
	#| 		first element is used as format for sprintf sub and the rest element as
	#| 		sprintf args;
	#| :$x - optional exception argument.]
	method trace(*@args, :$x) { ... }
	#|[Writes log with debug importance level.
	#| @args - data for logging. If the array has more then one element then the
	#| 		first element is used as format for sprintf sub and the rest element as
	#| 		sprintf args;
	#| :$x - optional exception argument.]
	method debug(*@args, :$x) { ... }
	#|[Writes log with info importance level.
	#| @args - data for logging. If the array has more then one element then the
	#| 		first element is used as format for sprintf sub and the rest element as
	#| 		sprintf args;
	#| :$x - optional exception argument.]
	method info(*@args, :$x) { ... }
	#|[Writes log with warn importance level.
	#| @args - data for logging. If the array has more then one element then the
	#| 		first element is used as format for sprintf sub and the rest element as
	#| 		sprintf args;
	#| :$x - optional exception argument.]
	method warn(*@args, :$x) { ... }
	#|[Writes log with error importance level.
	#| @args - data for logging. If the array has more then one element then the
	#| 		first element is used as format for sprintf sub and the rest element as
	#| 		sprintf args;
	#| :$x - optional exception argument.]
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