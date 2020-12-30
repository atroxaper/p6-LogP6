use Test;

use lib 'lib';
use lib './t/resource/Helpers';
use LogP6::Logger;
use LogP6::LoggerPure;
use IOString;
use LogP6 :configure;

plan 9;

my ($h1, $h2, $h3) = (IOString.new xx 3).list;
sub clean-io() { $_.clean for ($h1, $h2, $h3) }
writer(:name<w1>, :handle($h1));
writer(:name<w2>, :handle($h2));
my $x;
{
	die 'test exception';
	CATCH { default { $x = $_; .resume } }
}

subtest {
	plan 2;

	cliche(
		:name<simple>, :matcher<general>,
		:default-pattern<%msg>,
		:default-level($info), grooves => (
			'w1', filter(:level($error)),
			'w2', filter(:level($debug))
		)
	);

	my $general = get-logger('general');
	$general.error('g error');
	$general.info('g info');
	$general.debug('g debug');

	is $h1.clean, "g error\n", 'first filter is ok in general log';
	is $h2.clean, "g error\ng info\ng debug\n", 'first filter nok in general log';
}, 'simple reactive check';

subtest {
	plan 2;

	sub before($context) {
		if $context.msg ~~ /error/ {
			$context.level-set($error);
		}
		True;
	}

	cliche(
		:name<difficult>, :matcher<hard>,
		:default-pattern<%msg>,
		:default-level($info), grooves => (
			'w1', filter(:level($warn)),
			'w2', filter(:level($error), :!first-level-check,
				before-check => (&before,))
		)
	);

	my $hard = get-logger('hard');
	$hard.error('h error');
	$hard.warn('h warn');
	$hard.debug('h debug');
	$hard.trace('h trace but error');

	is $h1.clean, "h error\nh warn\n", 'first filter is ok in hard log';
	is $h2.clean, "h error\nh trace but error\n", 'first filter nok in hard log';
}, 'difficult reactive check';

subtest {
	plan 2;

	sub before($context) {
		$context.msg-set('U' ~ $context.msg);
		$context.level-set($trace);
		$context.x-set(Any);
		True;
	}

	cliche(
		:name<strange>, :matcher<reset>,
		:default-pattern('%level %msg%x{ $msg}'),
		:default-level($info), grooves => (
			'w1', filter(:level($warn), before-check => (&before,)),
			writer(:!auto-exceptions, :handle($h2)), filter(:level($info))
		)
	);

	my $reset = get-logger('reset');
	$reset.error('r error', :$x);
	$reset.warn('r warn');
	$reset.info('r info');

	is $h1.clean, "TRACE Ur error\nTRACE Ur warn\n",
		'first filter is ok in reset log';
	is $h2.clean, "ERROR r error test exception\nWARN r warn\nINFO r info\n",
		'first filter nok in reset log';
}, 'reset context';

subtest {
	plan 6;

	cliche(
		:name<sprintf>, :matcher<sprintf>,
		:default-pattern('%msg%x{ $msg}'),
		:default-level($info), grooves => (
			writer(:!auto-exceptions, :handle($h1)), filter()
		)
	);

	my $sprintf = get-logger('sprintf');

	$sprintf.info();
	is $h1.clean.trim, '', 'zero args info';

	$sprintf.info('simple log ' ~ 'boom');
	is $h1.clean.trim, 'simple log boom', 'one arg info';

	$sprintf.info('simple log with', ' x', :$x);
	is $h1.clean.trim, 'simple log with x test exception', 'two args with x info';

	$sprintf.infof();
	is $h1.clean.trim, '', 'zero args infof';

	$sprintf.infof('hard log %s', 'boom');
	is $h1.clean.trim, 'hard log boom', 'two args infof';

	$sprintf.infof('hard log %s with x', $x.message, :$x);
	is $h1.clean.trim, 'hard log test exception with x test exception',
		'two args with x infof';
}, 'sprintf';

subtest {
	plan 10;

	cliche(
		:name<ndc>, :matcher<ndc>,
		:default-pattern('%msg %ndc %mdc{foo}%mdc{oof}'),
		:default-level($info), grooves => ('w1', filter())
	);

	my $ndc = get-logger('ndc');

	$ndc.info('msg');
	is $h1.clean, "msg  \n", 'empty ndc and mdc';

	$ndc.ndc-push('n-one');
	$ndc.info('msg');
	is $h1.clean, "msg n-one \n", 'ndc one element';

	$ndc.ndc-push('n-two');
	$ndc.info('msg');
	is $h1.clean, "msg n-one n-two \n", 'ndc two elemets';

	$ndc.mdc-put('foo', 'bar');
	$ndc.info('msg');
	is $h1.clean, "msg n-one n-two bar\n", 'ndc two elements and mdc';

	$ndc.mdc-put('bar', 'foo');
	$ndc.info('msg');
	is $h1.clean, "msg n-one n-two bar\n", 'ndc two elements and mdc again';

	$ndc.mdc-put('oof', 'rab');
	$ndc.info('msg');
	is $h1.clean, "msg n-one n-two barrab\n", 'ndc two elements and mdc two';

	$ndc.mdc-remove('foo');
	$ndc.info('msg');
	is $h1.clean, "msg n-one n-two rab\n", 'ndc two elements and mdc second';

	$ndc.mdc-clean();
	$ndc.info('msg');
	is $h1.clean, "msg n-one n-two \n", 'ndc two elements and mdc clean';

	$ndc.ndc-pop();
	$ndc.info('msg');
	is $h1.clean, "msg n-one \n", 'ndc pop element';

	$ndc.ndc-clean();
	$ndc.info('msg');
	is $h1.clean, "msg  \n", 'ndc clean';
}, 'ndc and mdc';

subtest {
	plan 1;

	cliche(:name<mute>, :matcher<do-not-log>);

	my $mute = get-logger('do-not-log');
	does-ok $mute, LogP6::LoggerMute, 'create mute logger';
}, 'mute logger';

subtest {
	plan 2;
	use LogP6::Wrapper::SyncEach;

	cliche(:name<frame1>, :matcher<frame1>, grooves => (
		writer(:pattern('%msg %framename %framefile %frameline'), :handle($h1)),
		level($info)
	));
	cliche(:name<frame2>, :matcher<frame2>, grooves => (
		writer(:pattern('%msg %framename %framefile %frameline'), :handle($h1)),
		level($info)
	), :wrapper(LogP6::Wrapper::SyncEach::Wrapper.new));
	my $frame1 = get-logger('frame1');
	my $frame2 = get-logger('frame2');

	$frame1.info('line 1');
	my $l1 = $h1.clean;
	$frame1.infof('line 2');
	$frame2.infof('line 2');
	my @l2 = $h1.clean.trim.split("\n");
	isnt $l1, @l2[0], 'frames are different';
	is @l2[1].substr(0, *-1), @l2[0].substr(0, *-1), 'frames are the same';
}, 'different frame';

subtest {
	plan 5;

	my LogP6::Logger $log = get-logger('');

	$log.ndc-clean;
	$log.mdc-clean;
	$log.mdc-put('k', 'v');
	$log.mdc-put('v', 'k');
	my $dc = $log.dc-copy;
	$log.mdc-clean;
	nok $log.mdc-remove('k'), 'mdc is empty';
	$log.dc-restore($dc);
	is $log.mdc-remove('k'), 'v', 'mdc restore k';
	is $log.mdc-remove('v'), 'k', 'mdc restore v';

	$log.mdc-clean;
	$log.ndc-push: 'k';
	$log.ndc-push: 'v';
	$dc = $log.dc-copy;
	$log.ndc-clean;
	$log.dc-restore($dc);
	is $log.ndc-pop, 'v', 'ndc restore v';
	is $log.ndc-pop, 'k', 'ndc restore k';
}, 'dc-copy';

subtest {
	plan 13;

	my $h = IOString.new;
	cliche(:name<on>, :matcher<on>, grooves => (
		writer(:name<on>, :handle($h), :pattern<%msg>),
		level($info)
	));

	my $log = get-logger('on');

	$log.info('boom');
	is $h.clean.trim, 'boom', 'on w/o';

	ok $log.info-on, 'on info defined';
	nok $log.debug-on, 'on debug not defined';
	.log('magic') with $log.info-on;
	is $h.clean.trim, 'magic', 'on info with';
	.log('magic') with $log.debug-on;
	nok $h.clean, 'on debug with';
	$log.info-on.?log('magic again');
	is $h.clean.trim, 'magic again', 'on info .?';
	$log.debug-on.?log('magic again');
	nok $h.clean, 'on debug .?';

	.log('level') with $log.level-on($info);
	is $h.clean.trim, 'level', 'on level info with';
	.log('level') with $log.level-on($debug);
	nok $h.clean, 'on level debug with';

	my $i = 0;
	.log(++$i) with $log.debug-on;
	is $i, 0, 'do not calculate log with';
	$log.debug-on.?log(++$i);
	is $i, 1, 'unfortunatly do calculate log .?';
	nok $h.clean, 'nothing after not calculation';

	writer(:name<on>, :pattern('%framefile %msg'), :update);
	$log = get-logger('on');

	my $frame;
	.log('magic') with $log.info-on; $frame = callframe;
	is $h.clean.trim, $frame.file ~ ' magic', 'on callframe';
}, 'on';

done-testing;
