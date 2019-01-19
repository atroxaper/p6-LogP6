use Test;

use lib 'lib';
use LogP6 :configure;

sub some-sub1($context) {
	True;
}

sub some-sub2($context) {
	True;
}

subtest {
	plan 8;

	my $i = level($info);
	is $i.level, $info, 'info level';
	nok $i.first-level-check, 'info empty first-level check';
	nok $i.before-check, 'info empty before-check';
	nok $i.after-check, 'info empty after-check';

	is level($debug).level, $debug, 'debug level';
	is level($trace).level, $trace, 'trace level';
	is level($warn ).level, $warn,   'warn level';
	is level($error).level, $error, 'error level';

}, 'filter-level';

subtest {
	plan 40;

	my $f-wo-name = filter(:level($debug), :first-level-check,
		before-check => (&some-sub1,), after-check => (&some-sub2,));
	is $f-wo-name.level, $debug, 'f-wo-name level';
	ok $f-wo-name.first-level-check, 'f-wo-name first-level-check';
	is-deeply $f-wo-name.before-check, (&some-sub1,), 'f-wo-name before-check';
	is-deeply $f-wo-name.after-check, (&some-sub2,), 'f-wo-name after-check';

	my $f = filter(:name<f-name>, :level($warn), :!first-level-check,
		before-check => (&some-sub1,), after-check => (&some-sub2,), :create);
	is $f.name, 'f-name', 'f name';
	is $f.level, $warn, 'f level';
	nok $f.first-level-check, 'f first-level-check';
	is-deeply $f.before-check, (&some-sub1,), 'f before-check';
	is-deeply $f.after-check, (&some-sub2,), 'f after-check';
	is get-filter('f-name').name, 'f-name', 'get f-name';

	dies-ok { filter(:name<f-name>, :create) }, 'die create same filter';
	dies-ok { filter(:name<f-wo-name>, :update) }, 'die update no filter';

	$f = filter(:name<f-name>, :level($error), :first-level-check,
		after-check => (&some-sub1,), :update);
	is $f.name, 'f-name', 'f name before update';
	is $f.level, $warn, 'f level before update';
	nok $f.first-level-check, 'f first-level-check before update';
	is-deeply $f.before-check, (&some-sub1,), 'f before-check before update';
	is-deeply $f.after-check, (&some-sub2,), 'f after-check before update';

	$f = get-filter('f-name');
	is $f.name, 'f-name', 'f name update';
	is $f.level, $error, 'f level update';
	ok $f.first-level-check, 'f first-level-check update';
	is-deeply $f.before-check, (&some-sub1,), 'f before-check update same';
	is-deeply $f.after-check, (&some-sub1,), 'f after-check update';

	lives-ok { filter(:name<f-rep>, :replace) }, 'live replace no filter';
	ok get-filter('f-rep'), 'get created by replace filter';

	$f = filter(:name<f-name>, :level($trace), :!first-level-check, :replace);
	is $f.name, 'f-name', 'f name before replace';
	is $f.level, $error, 'f level before replace';
	ok $f.first-level-check, 'f first-level-check before replace';
	is-deeply $f.before-check, (&some-sub1,), 'f before-check before replace';
	is-deeply $f.after-check, (&some-sub1,), 'f after-check before replace';

	$f = get-filter('f-name');
	is $f.name, 'f-name', 'f name replace';
	is $f.level, $trace, 'f level replace';
	nok $f.first-level-check, 'f first-level-check replace';
	nok $f.before-check, 'f before-check replace';
	nok $f.after-check, 'f after-check replace';

	$f = filter(:name<f-name>, :remove);
	is $f.name, 'f-name', 'f name before remove';
	is $f.level, $trace, 'f level before remove';
	nok $f.first-level-check, 'f first-level-check before remove';
	nok $f.before-check, 'f before-check before remove';
	nok $f.after-check, 'f after-check before remove';

	nok get-filter('f-name'), 'f remove';

}, 'filter';

done-testing;
