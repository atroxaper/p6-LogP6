use Test;

use lib 'lib';
use LogP6::Logger;
use LogP6::Wrapper::SyncAbstract;

plan 8;

my $x;
{
	die 'exception';
	CATCH { default { $x = $_; .resume } }
}

class MockLogger does LogP6::Logger {
	has Str:D $.trait is required;
	has @.calls = ();

	method trait() {
		@!calls.push('trait');
		return $!trait;
	}

	method ndc-push($obj) { @!calls.push('ndc-push' ~ $obj) }
	method ndc-pop() { @!calls.push('ndc-pop') }
	method ndc-clean() { @!calls.push('ndc-clean') }
	method mdc-put($key, $obj) { @!calls.push('mdc-put' ~ $key ~ $obj) }
	method mdc-remove($key) { @!calls.push('mdc-remove' ~ $key) }
	method mdc-clean() { @!calls.push('mdc-clean') }
	method dc-copy() { @!calls.push('dc-copy') }
	method dc-restore($dc) { @!calls.push('dc-restore' ~ $dc) }
	method level($level, *@args, :$x) {
		@!calls.push('level' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method levelf($level, *@args, :$x) {
		@!calls.push('levelf' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method trace(*@args, :$x) {
		@!calls.push('trace' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method tracef(*@args, :$x) {
		@!calls.push('tracef' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method debug(*@args, :$x) {
		@!calls.push('debug' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method debugf(*@args, :$x) {
		@!calls.push('debugf' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method info(*@args, :$x) {
		@!calls.push('info' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method infof(*@args, :$x) {
		@!calls.push('infof' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method warn(*@args, :$x) {
		@!calls.push('warn' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method warnf(*@args, :$x) {
		@!calls.push('warnf' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method error(*@args, :$x) {
		@!calls.push('error' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method errorf(*@args, :$x) {
		@!calls.push('errorf' ~ @args.join('') ~ ((defined $x) ?? $x.message !! ''));
	}
	method trace-on() { @!calls.push('trace-on') }
	method debug-on() { @!calls.push('debug-on') }
	method info-on()  { @!calls.push('info-on') }
	method warn-on()  { @!calls.push('warn-on') }
	method error-on() { @!calls.push('error-on') }
	method level-on($level) { @!calls.push('level-on ' ~ $level) }
}

class SyncLogger is LogP6::Wrapper::SyncAbstract {
	has $.synced = 0;
	method sync($context) {
		with self.get-sync-obj() {
			is $_, $!synced, "synced $!synced";
			if $_ == 2 {
				self.update-aggr;
			}
		}
		self.put-sync-obj(++$!synced);
	}
}

my $mock = MockLogger.new(:trait<mock>);
my $update-times = 0;
my $updated-trait;
sub sync-logger($trait) {
	++$update-times;
	$updated-trait = $trait;
	return $mock;
}

my $wrapped = SyncLogger.new(:aggr($mock), get-fresh-logger => &sync-logger);

is $wrapped.trait, 'mock', 'wrap trait';
$wrapped.ndc-push('np');
$wrapped.mdc-put('mk', 'mo');
$wrapped.ndc-pop();
$wrapped.mdc-remove('km');
$wrapped.ndc-clean();
$wrapped.mdc-clean();
$wrapped.info('info', :$x);
$wrapped.debug('d');
$wrapped.warn('warn');
$wrapped.error('ERROR', :$x);
$wrapped.trace('ignore');
my $expected = <trait ndc-pushnp mdc-putmkmo ndc-pop mdc-removekm ndc-clean mdc-clean
	trait trait infoinfoexception
	trait trait debugd
	trait trait trait warnwarn
	trait trait errorERRORexception
	trait trait traceignore>.list.join(' ');
is $mock.calls.join(' '), $expected, 'good calls to aggr';
is $update-times, 1, 'updated one time';
is $updated-trait, 'mock', 'updated with right trait';

done-testing;
