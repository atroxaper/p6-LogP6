#|[Class on an object associated with each Thread.
#| Uses for storing Logger related things (like current log level or exception)
#| or user data in NDC array and MDC map. ]
unit class LogP6::Context;

# special avoid multi method in purpose of speed (for sure)

use LogP6::Level;

has $!msg;
has $!date;
has $!level;
has $!x;
has $!trait;
has $!thread;
has $!tid;
has $!tname;
has @!ndc = [];
has %!mdc = %();
has %!sync = %();
has $!callframe;

submethod BUILD() {
	$!thread = $*THREAD;
	$!tid = $!thread.id;
	$!tname = $!thread.name;
}

submethod TWEAK(
		:$msg, :$date, :$level, :$x, :$trait, :@ndc, :%mdc, :$callframe
) {
	$!msg = $msg;
	$!date = $date;
	$!level = $level;
	$!x = $x;
	$!trait = $trait;
	@!ndc := @ndc;
	%!mdc = %mdc;
	$!callframe = $callframe;
}

method copy() {
	return LogP6::Context.new(
		:$!msg, :$!date, :$!level, :$!x, :$!trait,
		:ndc(@!ndc.clone), :mdc(%!mdc.clone), :$!callframe
	);
}

#|[Gets Context object for current Thread.
# Throw exception in case Thread does not have a Context for now.
# It is not recommend to use the method as part of LogP6 API.
# It is internal method.]
method get-myself() {
	return $*THREAD._context;
}

# API methods below:

#| Sets values for current log message, level and user exception. Normally the
#| method is used by logger itself before each logging groove call.]
method reset($msg, $level, $x) {
	$!msg = $msg;
	$!level = $level;
	$!x = $x;
}

#|[Gets current log message. This is what the user want to be logged, what the
#| user pass in Logger methods like .info(). If the user used sprintf like style
#| of log arguments then msg() returns single rendered value.]
method msg() {
	$!msg;
}

#| Sets current log message.
method msg-set($msg) {
	$!msg = $msg;
}

#|[Gets current log level. This is how the user describes an important of
#| the message. Return LogP6::Level value.]
method level() {
	$!level;
}

#| Sets current log level.
method level-set($level) {
	$!level = $level;
}

#| Gets current exceptions user specified.
method x() {
	$!x;
}

#| Gets current exceptions.
method x-set($x) {
	$!x = $x;
}

#|[Gets value of the Nested Diagnostic Context array. User can push any value to
#| the NDC array and use the value in Writer. For example, push methods name for
#| tracking users flow in logs.]
method ndc() {
	@!ndc;
}

#| Push value to Nested Diagnostic Context array.
method ndc-push($obj) {
	@!ndc.push: $obj;
}

#| Pops the last value from Nested Diagnostic Context array.
method ndc-pop() {
	@!ndc.pop;
}

#| Cleans Nested Diagnostic Context array.
method ndc-clean() {
	@!ndc = [];
}

#|[Gets value of the Mapped Diagnostic Context map. User can put any value to
#| the MDC map and use the value in Writer. For example, pass to the MDC http
#| session number and track user's workflow in logs.]
method mdc() {
	%!mdc;
}

#| Gets value of the Mapped Diagnostic Context map for specified key.
method mdc-get($key) {
	%!mdc{$key};
}

#| Puts value to Mapped Diagnostic Context map.
method mdc-put($key, $obj) {
	%!mdc{$key} = $obj;
}

#|[Remove value from Mapped Diagnostic Context map for specified key.
#| Returns removed value.]
method mdc-remove($key) {
	%!mdc{$key}:delete;
}

#| Cleans Mapped Diagnostic Context map.
method mdc-clean() {
	%!mdc = %();
}

#|[Gets current DataTime.now value. The value will be cache until the date will
#| be set to undefined value by .date-set(), .date-clean() or clean() methods.
#| Normally the date value are reset before each logging without addition user's
#| actions.]
method date() {
	$!date //= DateTime.now;
}

#| Sets current date value.
method date-set($date) {
	$!date = $date;
}

#| Cleans current date value.
method date-clean() {
	$!date = DateTime;
}

#| Gets cached current $*THREAD.id.
method tid() {
	$!tid;
}
#| Gets cuched current $*THREAD.name
method tname() {
	$!tname;
}

#| Gets current logger trait.
method trait() {
	$!trait;
}

#|[Sets current logger trait. Normally the method is used by logger itself
#| before each logging.]
method trait-set($trait) {
	$!trait = $trait;
}

#|[Gets special object for synchronizations logic of logger. Normally the method
#| is used by synchronization logger wrappers.]
method sync($trait) {
	%!sync{$trait};
}

#|[Puts special object for synchronizations logic of logger. Normally the method
#| is used by synchronization logger wrappers.]
method sync-put($trait, $obj) {
	%!sync{$trait} = $obj;
}

#| Gets callframe of log caller level.
method callframe() {
	return $_ with $!callframe;
	# start with 3. it is much save and optimal
	for 3..* -> $level {
		with callframe($level) -> $frame {
			next unless $frame.code.name
					~~ any('trace', 'debug', 'info', 'warn', 'error');
			# +1 to caller code and +1 to go from `with` block
			$!callframe = callframe($level + 2);
			last;
		}
	}
	return $!callframe;
}

#|[Cleans all data values specified by logger (like date, msg, level,
#| exception and callframe). Normally the method is used by logger itself
#| after each logging.]
method clean() {
	$!callframe = $!date = $!msg = $!x = $!level = DateTime;
}