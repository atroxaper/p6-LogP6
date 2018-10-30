unit class LogP6::Context;

# special avoid multi method in purpose of speed (for sure)

use LogP6::Level;

has $!msg;
has $!level;

has $!thread;

submethod BUILD() {
	$!thread = $*THREAD;
}

method get-myself-to() {
	return $*THREAD.local<context> //= self.new;
}

# method for concrete object use

method reset($msg, $level) {
	$!msg = $msg;
	$!level = $level;
}

method msg-get() {
	$!msg;
}

method msg-set(Str:D $msg) {
	$!msg = $msg;
}

method level-get() {
	$!level;
}

method level-set(LogP6::Level $level) {
	$!level = $level;
}

method ndc-get() {
	$!thread.local<ndc> //= [];
}

method ndc-push($obj) {
	my $ndc := $!thread.local<ndc> //= [];
	$ndc.push: $obj;
}

method ndc-pop() {
	my $ndc := $!thread.local<ndc> //= [];
	$ndc.pop;
}

method ndc-clean() {
	$!thread.local<ndc> = [];
}

method mdc-get-all() {
	$!thread.local<mdc> //= %();
}

method mdc-get($key) {
	my $mdc := $!thread.local<mdc> //= %();
	$mdc{$key};
}

method mdc-put($key, $obj) {
	my $mdc := $!thread.local<mdc> //= %();
	$mdc{$key} = $obj;
}

method mdc-remove($key) {
	my $mdc := $!thread.local<mdc> //= %();
	$mdc{$key}:delete;
}

method mdc-clean() {
	$!thread.local<mdc> = %();
}

method date-get() {
	$!thread.local<date> //= DateTime.now;
}

method date-set(DateTime $date) {
	$!thread.local<date> = $date;
}

method date-clean() {
	$!thread.local<date>:delete;
}

method clean() {
	$!thread.local<date> = DateTime;
	$!msg = Str;
}
