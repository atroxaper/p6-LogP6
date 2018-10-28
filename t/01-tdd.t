use Test;

use lib 'lib';
use Log::Fast;
use Log::Fast::Level;

sub foo(Int $i) {
	say $i;
}

foo(debug);

my %o1 = %(:a<4>, :b<5>);
my %o2 = %o1.clone;
my $r = %o2<b>:delete;
say %o1;
say %o2;
say $r;

my $arg = 'Bar';
say so 'Foo::Bar' ~~ /$arg/;

#my Log::Fast $log-default;
#my Log::Fast $log-say;
#my Log::Fast $log-name;
#
#lives-ok { $log-default = Log::Fast::get-log }, 'get default log';
#lives-ok { $log-say = get-log('say') }, 'get default "say" log';
#lives-ok { $log-name = get-log('name') }, 'get log with name';
#
#sub foo(&bar:(:$info, :$log)) {
#	bar(:log<l>, :info<i>);
#	say 'top';
#	say &bar.WHAT;
#}

#foo(-> :$log, :$info { say $info, $log;});
#foo({ say $:info, $:log;});
#foo(sub (:$info, :$log) { say $info, $log; });

sub f(:$ff, :$pp) {
	say $ff, $pp;
}

sub fd(%args) {
	say %args;
}

my %r = ff => 1, pp => 2, dd => 12;

fd(%r);

#f(|%r);

#CATCH {
#	default {
#		say .^name, ': ', .Str;
#	}
#}

my class R {
	has $.boom;

	submethod BUILD(:$boom) {
		$!boom = $boom;
	}

	method f(:$ff, :$pp) {
		say $ff, $pp, 3;
	}
}
my R $e = R.new(:boom<4>, :noo<2>);
$e.f(|%r);

my @w = <ff dd>;
say %r{@w};

sub g() {
	say 'rr';
}

my %t = %();

g(|%t);

done-testing;
