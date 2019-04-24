use Test;

use lib 'lib';
use lib './t/resource/Helpers';
use LogP6 :configure;
use LogP6::WriterConf::Pattern;
use LogP6::Context;
use IOString;

plan 46;

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
	my IOString $io-str .= new;
	$io-str.print(|@pieces>>.show($context));
	$io-str.Str;
}

# simple
is parse-process('%trait %tid-%tname %ndc-%mdc{foo}:%msg:%level*%date*%x').trim,
		"test trait $tid-$tname 12 34-mdc-value:test message:INFO*23:54:09:123*" ~
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
is parse-process('%level{ERROR=warn}'), 'warn', 'default level length';
$level-line = '<%level{INFO=stay-for-a-wile-and-listen length=0}>';
is parse-process($level-line), '<ERROR>', 'level length 0 trace';
$context.level-set($warn);
is parse-process($level-line), '<WARN>', 'level length 0 warn';
$context.level-set($info);
is parse-process($level-line), '<stay-for-a-wile-and-listen>',
		'level length 0 info';

# %frame*
sub info($frame) {
	is parse-process('%framename %framefile %frameline').trim,
	$frame.code.name ~ ' ' ~ $frame.file ~ ' ' ~ $frame.line, 'frames';
}
sub foo() { info(callframe) }
foo;

# %trait
$context.trait-set('LogP6::Writer::Async::Std');
is parse-process('%trait{short=[.]5.4}'), 'LogP6.Writer.Async.Std', '[.]5.4';
is parse-process('%trait{short=[.]5}' ),  'LogP6.Writer.Async.Std', '[.]5';
is parse-process('%trait{short=[.]4.2}'), 'LogP6.Writer.Async.Std', '[.]4.4';
is parse-process('%trait{short=[.]4}' ),  'LogP6.Writer.Async.Std', '[.]4';
is parse-process('%trait{short=[.]3.2}'), 'Lo.Writer.Async.Std', '[.]3.2';
is parse-process('%trait{short=[.]3}' ),  'Writer.Async.Std', '[.]3';
is parse-process('%trait{short=[.]2.3}'), 'Log.Wri.Async.Std', '[.]2.3';
is parse-process('%trait{short=[.]2}' ),  'Async.Std', '[.]2';
is parse-process('%trait{short=[.]1.1}'), 'L.W.A.Std', '[.]1.1';
is parse-process('%trait{short=[.]1}' ),  'Std', '[.]1';
is parse-process('%trait{short=[.]0.4}'), 'LogP6.Writer.Async.Std', '[.]0.4';
is parse-process('%trait{short=[.]0}' ),  'LogP6.Writer.Async.Std', '[.]0';
is parse-process('%trait{short=[.]-0.2}'),'LogP6.Writer.Async.Std', '[.]-0.2';
is parse-process('%trait{short=[.]-0}' ), 'LogP6.Writer.Async.Std', '[.]-0';
is parse-process('%trait{short=[.]-1.4}'),'LogP.Writer.Async.Std', '[.]-1.4';
is parse-process('%trait{short=[.]-1}' ), 'Writer.Async.Std', '[.]-1';
is parse-process('%trait{short=[.]-2.0}'),'Async.Std', '[.]-2.0';
is parse-process('%trait{short=[.]-2}' ), 'Async.Std', '[.]-2';
is parse-process('%trait{short=[.]-3.1}'),'L.W.A.Std', '[.]-3.1';
is parse-process('%trait{short=[.]-3}' ), 'Std', '[.]-3';
is parse-process('%trait{short=[.]-4.0}'),'LogP6.Writer.Async.Std', '[.]-4.0';
is parse-process('%trait{short=[.]-4}' ), 'LogP6.Writer.Async.Std', '[.]-4';
is parse-process('%trait{short=[.]-5.2}'), 'LogP6.Writer.Async.Std', '[.]-5.2';
is parse-process('%trait{short=[.]-5}' ), 'LogP6.Writer.Async.Std', '[.]-5';
$context.trait-set('LogP6::Writer::Async');
is parse-process('%trait{sprintf=%.2s}'), 'Lo', '%.2s';
is parse-process('%trait{sprintf=%21s}'), ' LogP6::Writer::Async', '%21s';
is parse-process('%trait{sprintf=%-21s}'), 'LogP6::Writer::Async ', '%-21s';

# %color
$context.level-set($warn);
$context.msg-set('msg');
is parse-process('%msg [%color%level%color{reset}]'),
		"msg [\e[35mWARN\e[0m]", 'color empty with reset';
is parse-process('%msg [%color{WARN=34}%level%color{reset}]'),
		"msg [\e[34mWARN\e[0m]", 'color WARN with reset';
$context.level-set($error);
is parse-process('%msg [%color{WARN=34}%level%color{reset}]'),
		"msg [\e[31mERROR\e[0m]", 'color WARN error with reset';
is parse-process('%msg [%color%level]'),
		"msg [\e[31mERROR]\e[0m", 'color empty without reset';
is parse-process('%msg [%color%level%creset]'),
		"msg [\e[31mERROR\e[0m]", 'color empty with creset';

done-testing;
