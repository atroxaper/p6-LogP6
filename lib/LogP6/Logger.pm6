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
	#|[Writes log with specified importance level.
	#| $level - importance level of log
	#| @args - data for logging. Elements of the array will be concatenated with
	#|    empty string;
	#| :$x - optional exception argument.]
	method level($level, *@args, :$x) { ... }
	#|[Writes log with specified importance level.
	#| $level - importance level of log
	#| @args - data for logging. The first element is used as sprintf format
	#|    and the rest element as sprintf args;
	#| :$x - optional exception argument.]
	method levelf($level, *@args, :$x) { ... }
	#|[Writes log with trace importance level.
	#| @args - data for logging. Elements of the array will be concatenated with
	#|    empty string;
	#| :$x - optional exception argument.]
	method trace(*@args, :$x) { ... }
	#|[Writes log with trace importance level.
	#| @args - data for logging. The first element is used as sprintf format
	#|    and the rest element as sprintf args;
	#| :$x - optional exception argument.]
	method tracef(*@args, :$x) { ... }
	#|[Writes log with debug importance level.
	#| @args - data for logging. Elements of the array will be concatenated with
	#|    empty string;
	#| :$x - optional exception argument.]
	method debug(*@args, :$x) { ... }
	#|[Writes log with debug importance level.
	#| @args - data for logging. The first element is used as sprintf format
	#|    and the rest element as sprintf args;
	#| :$x - optional exception argument.]
	method debugf(*@args, :$x) { ... }
	#|[Writes log with info importance level.
	#| @args - data for logging. Elements of the array will be concatenated with
	#|    empty string;
	#| :$x - optional exception argument.]
	method info(*@args, :$x) { ... }
	#|[Writes log with info importance level.
	#| @args - data for logging. The first element is used as sprintf format
	#|    and the rest element as sprintf args;
	#| :$x - optional exception argument.]
	method infof(*@args, :$x) { ... }
	#|[Writes log with warn importance level.
	#| @args - data for logging. Elements of the array will be concatenated with
	#|    empty string;
	#| :$x - optional exception argument.]
	method warn(*@args, :$x) { ... }
	#|[Writes log with warn importance level.
	#| @args - data for logging. The first element is used as sprintf format
	#|    and the rest element as sprintf args;
	#| :$x - optional exception argument.]
	method warnf(*@args, :$x) { ... }
	#|[Writes log with error importance level.
	#| @args - data for logging. Elements of the array will be concatenated with
	#|    empty string;
	#| :$x - optional exception argument.]
	method error(*@args, :$x) { ... }
	#|[Writes log with error importance level.
	#| @args - data for logging. The first element is used as sprintf format
	#|    and the rest element as sprintf args;
	#| :$x - optional exception argument.]
	method errorf(*@args, :$x) { ... }
	#|[Check if a log will be written with trace importance level.
	#| Returns Any if not, or `little logger` with `log` and `logf` methods
	#| to write a log message with trace level.]
	method trace-on() { ... }
	#|[Check if a log will be written with debug importance level.
	#| Returns Any if not, or `little logger` with `log` and `logf` methods
	#| to write a log message with debug level.]
	method debug-on() { ... }
	#|[Check if a log will be written with info importance level.
	#| Returns Any if not, or `little logger` with `log` and `logf` methods
	#| to write a log message with info level.]
	method info-on() { ... }
	#|[Check if a log will be written with warn importance level.
	#| Returns Any if not, or `little logger` with `log` and `logf` methods
	#| to write a log message with warn level.]
	method warn-on() { ... }
	#|[Check if a log will be written with error importance level.
	#| Returns Any if not, or `little logger` with `log` and `logf` methods
	#| to write a log message with error level.]
	method error-on() { ... }
	#|[Check if a log will be written with specified importance level.
	#| Returns Any if not, or `little logger` with `log` and `logf` methods
	#| to write a log message with specified level.]
	method level-on($level) { ... }
}

class LogP6::IfLogger {
	has $.log;
	has $.level;

	method log(*@args, :$x) { $!log.level($!level, |@args, :$x) }
	method logf(*@args, :$x) { $!log.levelf($!level, |@args, :$x) }
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