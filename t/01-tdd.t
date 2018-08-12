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

done-testing;
