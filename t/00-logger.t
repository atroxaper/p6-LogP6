use Test;

use lib 'lib';
use lib './t/resource/Helpers';
use LogP6::Logger;
use LogP6::LoggerPure;
use IOString;
use LogP6 :configure;

plan 7;

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
	is $h2.clean, "ERROR r error test exception\nWARN  r warn\nINFO  r info\n",
		'first filter nok in reset log';
}, 'reset context';

subtest {
	plan 4;

	cliche(
		:name<sprintf>, :matcher<sprintf>,
		:default-pattern('%msg%x{ $msg}'),
		:default-level($info), grooves => (
			writer(:!auto-exceptions, :handle($h1)), filter()
		)
	);

	my $sprintf = get-logger('sprintf');

	$sprintf.info('simple log ' ~ 'boom');
	is $h1.clean.trim, 'simple log boom', 'one arg';

	$sprintf.info('simple log with x', :$x);
	is $h1.clean.trim, 'simple log with x test exception', 'one arg with x';

	$sprintf.info('hard log %s', 'boom');
	is $h1.clean.trim, 'hard log boom', 'two args';

	$sprintf.info('hard log %s with x', $x.message, :$x);
	is $h1.clean.trim, 'hard log test exception with x test exception',
		'two args with x';
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
	plan 1;

	cliche(:name<frame>, :matcher<frame>, grooves => (
		writer(:pattern('%msg %framename %framefile %frameline'), :handle($h1)),
		level($info)
	));
	my $frame = get-logger('frame');

	$frame.info('line 1');
	my $l1 = $h1.clean;
	$frame.info('line 2');
	my $l2 = $h1.clean;
	isnt $l1, $l2, 'frames are different';
}, 'different frame';

done-testing;
