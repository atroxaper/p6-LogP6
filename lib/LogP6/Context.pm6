unit class LogP6::Context;

# special avoid multi method in purpose of speed (for sure)

use LogP6::Level;

has $!msg;
has $!level;
has $!x;
has $!trait;
has $!thread;
has $!tid;
has $!tname;
has $!local = %();

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
	$!local<ndc> //= [];
}

method ndc-push($obj) {
	my $ndc := $!local<ndc> //= [];
	$ndc.push: $obj;
}

method ndc-pop() {
	my $ndc := $!local<ndc> //= [];
	$ndc.pop;
}

method ndc-clean() {
	$!local<ndc> = [];
}

method mdc() {
	$!local<mdc> //= %();
}

method mdc-get($key) {
	my $mdc := $!local<mdc> //= %();
	$mdc{$key};
}

method mdc-put($key, $obj) {
	my $mdc := $!local<mdc> //= %();
	$mdc{$key} = $obj;
}

method mdc-remove($key) {
	my $mdc := $!local<mdc> //= %();
	$mdc{$key}:delete;
}

method mdc-clean() {
	$!local<mdc> = %();
}

method date() {
	$!local<date> //= DateTime.now;
}

method date-set(DateTime $date) {
	$!local<date> = $date;
}

method date-clean() {
	$!local<date>:delete;
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

method clean() {
	$!local<date> = DateTime;
	$!msg = Str;
	$!x = Any;
}