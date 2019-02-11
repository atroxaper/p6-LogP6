use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::Filter::Std;
use LogP6::Context;

plan 4;

my @before-action = [];
my @after-action = [];

sub beforeTrue($context) {
	@before-action.push: 'bTrue';
	True;
}

sub beforeX($context) {
	@before-action.push: 'bX';
	$context.x // True;
}

sub afterTrue($context) {
	@after-action.push: 'aTrue';
	True;
}

sub afterX($context) {
	@after-action.push: 'aX';
	$context.x // True;
}

sub clean() {
	@before-action = [];
	@after-action = [];
}

sub context($level, $x) {
	my LogP6::Context $context .= new;
	$context.level-set: $level;
	$context.x-set: $x;
	clean;
	$context;
}

subtest {
	plan 9;

	my $f-with-name = filter(:name<f-name>, :level($trace), :!first-level-check,
			before-check => (&beforeTrue,), after-check => (&afterTrue,));

	my $f-get = get-filter('f-name');
	ok $f-get ~~ LogP6::FilterConf::Std:D, 'get defined';
	is $f-get.name, 'f-name', 'right name';
	is $f-get.level, $trace, 'right level';
	is $f-get.first-level-check, False, 'right first-level-check';
	is-deeply $f-get.before-check, (&beforeTrue,), 'right before-check';
	is-deeply $f-get.after-check, (&afterTrue,), 'right after-check';
	is $f-with-name, $f-get, 'from factory and from get are the same';

	my $f-get-empty = get-filter('not-exitst');
	ok $f-get-empty ~~ LogP6::FilterConf:U, 'get not exist as undefined conf';
	isnt $f-with-name, $f-get-empty, 'from factory and empty are not the same';
}, 'create named filter configuration by factory';

subtest {
	plan 7;

	my $f-with-name = get-filter('f-name');
	my $anothre-name = $f-with-name.clone-with-name('another');
	is $f-with-name.name, 'f-name', 'source has origin name';
	is $anothre-name.name, 'another', 'clone has another name';
	is $f-with-name.level, $anothre-name.level, 'both have the same level';
	is $f-with-name.first-level-check, $anothre-name.first-level-check,
			'both have the same first-level-check';
	is-deeply $f-with-name.before-check, $anothre-name.before-check,
			'both have the same before check';
	is-deeply $f-with-name.after-check, $anothre-name.after-check,
			'both have the same after check';
	isnt $f-with-name.WHICH, $anothre-name.WHICH, 'WHICHes are not the same';
}, 'clone filter configuration';

subtest {
	plan 1;

	my $f-with-name = get-filter('f-name');
	lives-ok { $f-with-name.self-check }, 'filter configuration self check pass';
}, 'self-check filter configuration';

subtest {
	plan 24;

	my LogP6::Context $context .= new;

	ok get-filter('f-name').make-filter(:default-level($info))
			~~ LogP6::Filter::Std:D, 'make filter proper value';

	my $reactive-level = filter(
			:name<reactive-level>, :level($warn),
			before-check => (&beforeX, &beforeTrue,),
			after-check => (&afterX, &afterTrue,))
			.make-filter(:default-level($info), :default-first-level-check);
	is ($trace, $debug, $info, $warn, $error)
			.map(-> $l { $reactive-level.reactive-check($l) }),
			(False, False, False, True, True), 'self level is main';

	my $reactive = filter(
			:name<reactive>,
			before-check => (&beforeX, &beforeTrue,),
			after-check => (&afterX, &afterTrue,))
			.make-filter(:default-level($info), :default-first-level-check);
	is ($trace, $debug, $info, $warn, $error)
			.map(-> $l { $reactive.reactive-check($l) }),
			(False, False, True, True, True), 'self level is empty, took default';

	my $nonreactive = filter(
			:name<nonreactive>,
			:level($warn),
			:!first-level-check,
			before-check => (&beforeX, &beforeTrue,),
			after-check => (&afterX, &afterTrue,))
			.make-filter(:default-level($info), :default-first-level-check);
	is ($trace, $debug, $info, $warn, $error)
			.map(-> $l { $nonreactive.reactive-check($l) }),
			(True, True, True, True, True), 'noreactive does not react';

	nok $reactive.do-before(context($debug, True)), 'reactive not pass';
	is @before-action, [], 'reactive not pass to filters';
	ok $reactive.do-before(context($info, True)), 'reactive pass';
	is @before-action, <bX bTrue>, 'reactive pass to filters';
	nok $reactive.do-before(context($info, False)), 'reactive pass';
	is @before-action, <bX>, 'reactive pass to filters';

	nok $nonreactive.do-before(context($info, True)), 'nonreactive not pass';
	is @before-action, <bX bTrue>, 'nonreactive not pass last level check';
	ok $nonreactive.do-before(context($warn, True)), 'nonreactive pass';
	is @before-action, <bX bTrue>, 'reactive pass last level check';
	nok $nonreactive.do-before(context($warn, False)),
			'nonreactive not pass filter';
	is @before-action, <bX>, 'nonreactive not pass filter';

	for $reactive, $nonreactive -> $filter {
		$filter.do-after(context($trace, True));
		is @after-action, <aX aTrue>, 'filter after trace good';
		$filter.do-after(context($error, True));
		is @after-action, <aX aTrue>, 'filter after error good';
		$filter.do-after(context($trace, False));
		is @after-action, <aX>.Array, 'filter after trace not good';
		$filter.do-after(context($error, False));
		is @after-action, <aX>.Array, 'filter after error not good';
	}

}, 'make and use filter';

done-testing;
