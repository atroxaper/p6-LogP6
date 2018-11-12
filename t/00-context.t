use Test;

use lib 'lib';
use LogP6::Logger;
use LogP6::Level;

my LogP6::Context $context = get-context();

# create
ok $context.defined, 'get-context';

# threads
is $context.tname, $*THREAD.name, 'tname';
is $context.tid, $*THREAD.id, 'tid';

# msg and level
nok $context.msg.defined, 'default msg';
$context.msg-set('setted');
is $context.msg, 'setted', 'setted msg';
nok $context.level.defined, 'default level';
$context.level-set('boom');
is $context.level, 'boom', 'can set any level';
$context.level-set(info);
is $context.level, info, 'set properly level';
$context.reset('resetted', trace);
is $context.msg, 'resetted', 'resetted msg';
is $context.level, trace, 'resetted level';

# trait
nok $context.trait, 'default trait';
$context.trait-set('tr');
is $context.trait, 'tr', 'setted trait';

# ndc
lives-ok { $context.ndc }, 'ndc without trait';
lives-ok { $context.ndc-push('') }, 'ndc-push without trait';
lives-ok { $context.ndc-pop }, 'ndc-pop without trait';
lives-ok { $context.ndc-clean }, 'ndc-clean without trait';
for Any, 'trait' -> $tr {
	is-deeply $context.ndc($tr), [], "ndc ($($tr // ''))";
	$context.ndc-push('p1', $tr);
	is-deeply $context.ndc($tr), <p1>.Array, "ndc-push p1 ($($tr // ''))";
	$context.ndc-push('p2', $tr);
	is-deeply $context.ndc($tr), <p1 p2>.Array, "ndc-push p2 ($($tr // ''))";
	$context.ndc-pop($tr);
	is-deeply $context.ndc($tr), <p1>.Array, "ndc-pop ($($tr // ''))";
	$context.ndc-clean($tr);
	is-deeply $context.ndc($tr), [], "ndc-clean ($($tr // ''))";
}

# mdc
lives-ok { $context.mdc }, 'mdc without trait';
lives-ok { $context.mdc-put('', '') }, 'mdc-put without trait';
lives-ok { $context.mdc-get('') }, 'mdc-get without trait';
lives-ok { $context.mdc-remove('') }, 'mdc-remove without trait';
lives-ok { $context.mdc-clean }, 'mdc-clean without trait';
for Any, 'trait' -> $tr {
	is-deeply $context.mdc($tr), %(), "mdc ($($tr // ''))";
	$context.mdc-put('k1', 'v1', $tr);
	is-deeply $context.mdc($tr), %(:k1<v1>), "mdc-put k1 ($($tr // ''))";
	$context.mdc-put('k2', 'v2', $tr);
	is-deeply $context.mdc($tr), %(:k1<v1>, :k2<v2>), "mdc-put k2 ($($tr // ''))";
	is $context.mdc-get('k1', $tr), 'v1', "mdc get k1 ($($tr // ''))";
	is $context.mdc-get('p1', $tr), Any, "mdc get p1 ($($tr // ''))";
	$context.mdc-remove('k1', $tr);
	is $context.mdc-get('k1', $tr), Any, "mdc get k1 after remove ($($tr // ''))";
	$context.mdc-clean($tr);
	is-deeply $context.mdc($tr), %(), "mdc-clean ($($tr // ''))";
}

# date
my $default-date = $context.date;
my $setted-date = DateTime.now;
ok $default-date.defined, 'default date';
$context.date-set($setted-date);
is $context.date, $setted-date, 'setted date';
isnt $context.date, $default-date, 'setted date is not default date';
$context.date-clean;
my $new-default = $context.date;
ok $new-default.defined, 'new default date';
isnt $new-default, $default-date, 'new default date is not default date';
isnt $new-default, $setted-date, 'new default date is not setted date';

# sync
nok $context.sync('tr').defined, 'default sync';
$context.sync-put('tr', 'obj1');
is $context.sync('tr'), 'obj1', 'putted first sync';
$context.sync-put('tr', 'obj2');
is $context.sync('tr'), 'obj2', 'putted second sync';
$context.sync-put('tr', Any);
is $context.sync('tr'), Any, 'putted Any sync';

# x
nok $context.x, 'default x';
$context.x-set('boom');
is $context.x, 'boom', 'can set any x';
$context.x-set(X::AdHoc.new);
is $context.x, X::AdHoc.new, 'setted x';

# clean
$context.clean;
ok $context.date.defined, 'clean all with date defined';
isnt $context.date, $new-default, 'clean all with date not old';
nok $context.msg, 'clean all with msg';
nok $context.x, 'clean all with x';

done-testing;
