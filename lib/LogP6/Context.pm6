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

submethod BUILD() {
	$!thread = $*THREAD;
	$!tid = $!thread.id;
	$!tname = $!thread.name;
# TODO
#	die "bla bla bla";
#	CATCH {
#		when X::AdHoc {
#			$!x = $_;
#			.resume;
#		}
#	}
}

method get-myself() {
	return $*THREAD._context;
}

# method for concrete object use

method reset($msg, $level) {
	$!msg = $msg;
	$!level = $level;
}

method msg() {
	$!msg;
}

method msg-set(Str:D $msg) {
	$!msg = $msg;
}

method level() {
	$!level;
}

method level-set(LogP6::Level $level) {
	$!level = $level;
}

method ndc() {
	@!ndc;
}

method ndc-push($obj) {
	@!ndc.push: $obj;
}

method ndc-pop() {
	@!ndc.pop;
}

method ndc-clean() {
	@!ndc = [];
}

method mdc() {
	%!mdc;
}

method mdc-get($key) {
	%!mdc{$key};
}

method mdc-put($key, $obj) {
	%!mdc{$key} = $obj;
}

method mdc-remove($key) {
	%!mdc{$key}:delete;
}

method mdc-clean() {
	%!mdc = %();
}

method date() {
	$!date //= DateTime.now;
}

method date-set(DateTime $date) {
	$!date = $date;
}

method date-clean() {
	$!date = DateTime;
}

method tid() {
	$!tid;
}

method tname() {
	$!tname;
}

method trait-set($trait) {
	$!trait = $trait;
}

method trait() {
	$!trait;
}

method x() {
	$!x;
}

method x-set($x) {
	$!x = $x;
}

method sync($trait) {
	%!sync{$trait};
}

method sync-put($trait, $obj) {
	%!sync{$trait} = $obj;
}

method clean() {
	$!date = DateTime;
	$!msg = Str;
	$!x = Any;
}