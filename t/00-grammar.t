use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::Pattern;
use LogP6::Context;
use LogP6::Helpers::IOString;

plan 10;

my LogP6::Context $context .= new;
$context.level-set($info);
$context.msg-set("test message");
$context.date-set(DateTime.new(:year(2018), :month(11), :day(3),
		:hour(23), :minute(54), :second(9.1234), :timezone(7200)));
{
	die 'test exception';
	CATCH { default { $context.x-set: $_; .resume } }
}
$context.trait-set('test trait');
my $tid = $*THREAD.id;
my $tname = $*THREAD.name;
my $backtrace = $context.x.backtrace.Str.chomp;
$context.ndc-push: 12;
$context.ndc-push: 34;
$context.mdc-put('foo', 'mdc-value');

sub parse-process($pattern) {
	my @pieces := Grammar.parse($pattern, actions => Actions).made;
	my LogP6::Helpers::IOString $io-str .= new;
	$io-str.print(|@pieces>>.show($context));
	$io-str.Str;
}

# simple
is parse-process('%trait %tid-%tname %ndc-%mdc{foo}:%msg:%level*%date*%x').trim,
		"test trait $tid-$tname 12 34-mdc-value:test message:INFO *23:54:09:123*" ~
		"Exception X::AdHoc: test exception\n" ~ $backtrace,
		'full pattern without preferences';

# %x
is parse-process('%x{$name}:%x{$msg};%x{$msg_$name_' ~ "\n" ~'$trace}').trim,
		"X::AdHoc:test exception;test exception_X::AdHoc_\n" ~ $backtrace,
		'%x pattern';

# %date
is parse-process('%date{$yyyy-$yy-$MM-$MMM-$dd $hh:$mm:$ss,$mss $z}'),
		'2018-18-11-Nov-03 23:54:09,123 7200',
		'%date pattern';

# %level
my $level-line = '%level{WARN=warn DEBUG=DeBuG TRACE=trAce INFO=info length=';
$context.level-set($trace);
is parse-process($level-line ~ '2}'), 'tr', 'level length 2';
is parse-process($level-line ~ '3}'), 'trA', 'level length 3';
$context.level-set($info);
is parse-process($level-line ~ '6}'), 'info  ', 'level length 6';
is parse-process($level-line ~ '1}'), 'i', 'level length 1';
$context.level-set($error);
is parse-process($level-line ~ '1}'), 'E', 'default level length 1';
is parse-process($level-line ~ '3}'), 'ERR', 'default level length 3';
is parse-process('%level{ERROR=warn}'), 'warn ', 'default level length';

done-testing;
