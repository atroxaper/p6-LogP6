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
	plan 55;

	my $f-wo-name = filter(:level($debug), :first-level-check,
		before-check => (&some-sub1,), after-check => (&some-sub2,));
	is $f-wo-name.level, $debug, 'f-wo-name level';
	ok $f-wo-name.first-level-check, 'f-wo-name first-level-check';
	is-deeply $f-wo-name.before-check, (&some-sub1,), 'f-wo-name before-check';
	is-deeply $f-wo-name.after-check, (&some-sub2,), 'f-wo-name after-check';

	my $f = filter(:name<f-name>, :level($warn), :!first-level-check,
		before-check => (&some-sub1,), after-check => (&some-sub2,), :create);
	my $save = $f;
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

	nok filter(:name<f-rep>, :replace), 'live replace no filter';
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

	filter($f, :create);

	$f = get-filter('f-name');
	is $f.name, 'f-name', 'f name recreate';
	is $f.level, $trace, 'f level recreate';
	nok $f.first-level-check, 'f first-level-check recreate';
	nok $f.before-check, 'f before-check recreate';
	nok $f.after-check, 'f after-check recreate';

	$f = filter($save, :replace);
	is $f.name, 'f-name', 'f name before rereplace';
	is $f.level, $trace, 'f level before rereplace';
	nok $f.first-level-check, 'f first-level-check before rereplace';
	nok $f.before-check, 'f before-check before rereplace';
	nok $f.after-check, 'f after-check before rereplace';

	$f = get-filter('f-name');
	is $f.name, 'f-name', 'f name rereplace';
	is $f.level, $warn, 'f level rereplace';
	nok $f.first-level-check, 'f first-level-check rereplace';
	is-deeply $f.before-check, (&some-sub1,), 'f before-check rereplace';
	is-deeply $f.after-check, (&some-sub2,), 'f after-check rereplace';

}, 'filter';

my $pattern1 = '[%date{$hh:$mm:$ss}][%level{length=5}] %msg';
my $pattern2 = '%level| %msg';

subtest {

	plan 45;

	my $w-wo-name = writer(:pattern($pattern1), :auto-exceptions,
		handle => $*ERR);
	is $w-wo-name.pattern, $pattern1, 'w-wo-name pattern';
	ok $w-wo-name.auto-exceptions, 'w-wo-name auto-exceptions';
	is $w-wo-name.handle, $*ERR, 'w-wo-name handle';

	my $w = writer(:name<w-name>, :pattern($pattern2), :!auto-exceptions,
		handle => $*OUT, :create);
	my $save = $w;
	is $w.name, 'w-name', 'w name';
	is $w.pattern, $pattern2, 'w pattern';
	nok $w.auto-exceptions, 'w auto-exceptions';
	is $w.handle, $*OUT, 'w handle';
	is get-writer('w-name').name, 'w-name', 'get f-name';

	dies-ok { writer(:name<w-name>, :create) }, 'die create same writer';
	dies-ok { writer(:name<w-wo-name>, :update) }, 'die update no writer';

	$w = writer(:name<w-name>, :pattern($pattern1), :update);
	is $w.name, 'w-name', 'w name before update';
	is $w.pattern, $pattern2, 'w pattern before update';
	nok $w.auto-exceptions, 'w auto-exceptions before update';
	is $w.handle, $*OUT, 'w handle before update';

	$w = get-writer('w-name');
	is $w.name, 'w-name', 'w name update';
	is $w.pattern, $pattern1, 'w pattern update';
	nok $w.auto-exceptions, 'w auto-exceptions update';
	is $w.handle, $*OUT, 'w handle update';

	nok writer(:name<w-rep>, :replace), 'live replace no writer';
	ok get-filter('f-rep'), 'get created by replace writer';

	$w = writer(:name<w-name>, :pattern($pattern2), :replace);
	is $w.name, 'w-name', 'w name before replace';
	is $w.pattern, $pattern1, 'w pattern before replace';
	nok $w.auto-exceptions, 'w auto-exceptions before replace';
	is $w.handle, $*OUT, 'w handle before replace';

	$w = get-writer('w-name');
	is $w.name, 'w-name', 'w name replace';
	is $w.pattern, $pattern2, 'w pattern replace';
	nok $w.auto-exceptions, 'w auto-exceptions replace';
	nok $w.handle, 'w handle replace';

	$w = writer(:name<w-name>, :remove);
	is $w.name, 'w-name', 'w name before remove';
	is $w.pattern, $pattern2, 'w pattern before remove';
	nok $w.auto-exceptions, 'w auto-exceptions before remove';
	nok $w.handle, 'w handle before remove';

	nok get-writer('w-name'), 'w remove';

	writer($w, :create);

	$w = get-writer('w-name');
	is $w.name, 'w-name', 'w name recreate';
	is $w.pattern, $pattern2, 'w pattern recreate';
	nok $w.auto-exceptions, 'w auto-exceptions recreate';
	nok $w.handle, 'w handle recreate';

	$w = writer($save, :replace);
	is $w.name, 'w-name', 'w name before rereplace';
	is $w.pattern, $pattern2, 'w pattern before rereplace';
	nok $w.auto-exceptions, 'w auto-exceptions before rereplace';
	nok $w.handle, 'w handle before rereplace';

	$w = get-writer('w-name');
	is $w.name, 'w-name', 'w name rereplace';
	is $w.pattern, $pattern2, 'w pattern rereplace';
	nok $w.auto-exceptions, 'w auto-exceptions rereplace';
	is $w.handle, $*OUT, 'w handle rereplace';

}, 'writer';

done-testing;
