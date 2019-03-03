use Test;

use lib 'lib';
use LogP6::Logger;
use LogP6::Level;

plan 44;

my LogP6::Context $context = get-context();

# create
ok $context.defined, 'get-context';

# threads
is $context.tname, $*THREAD.name, 'tname';
is $context.tid, $*THREAD.id, 'tid';

# msg, level and x
nok $context.msg.defined, 'default msg';
$context.msg-set('setted');
is $context.msg, 'setted', 'setted msg';
nok $context.level.defined, 'default level';
$context.level-set('boom');
is $context.level, 'boom', 'can set any level';
$context.level-set(info);
is $context.level, info, 'set properly level';
nok $context.x.defined, 'default x';
$context.x-set(X::AdHoc.new);
is $context.x, X::AdHoc.new, 'setted x';
$context.reset('resetted', trace, X::AdHoc.new(:payload<p>));
is $context.msg, 'resetted', 'resetted msg';
is $context.level, trace, 'resetted level';
is $context.x.payload, 'p', 'resetted x';

# trait
nok $context.trait, 'default trait';
$context.trait-set('tr');
is $context.trait, 'tr', 'setted trait';

# ndc
is-deeply $context.ndc, [], 'ndc';
$context.ndc-push('p1');
is-deeply $context.ndc, <p1>.Array, 'ndc-push p1';
$context.ndc-push('p2');
is-deeply $context.ndc, <p1 p2>.Array, 'ndc-push p2';
$context.ndc-pop;
is-deeply $context.ndc, <p1>.Array, 'ndc-pop';
$context.ndc-clean;
is-deeply $context.ndc, [], 'ndc-clean';

# mdc
is-deeply $context.mdc, %(), 'mdc';
$context.mdc-put('k1', 'v1');
is-deeply $context.mdc, %(:k1<v1>), 'mdc-put k1';
$context.mdc-put('k2', 'v2');
is-deeply $context.mdc, %(:k1<v1>, :k2<v2>), 'mdc-put k2';
is $context.mdc-get('k1'), 'v1', 'mdc get k1';
is $context.mdc-get('p1'), Any, 'mdc get p1';
$context.mdc-remove('k1');
is $context.mdc-get('k1'), Any, 'mdc get k1 after remove';
$context.mdc-clean;
is-deeply $context.mdc, %(), 'mdc-clean';

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
nok $context.level, 'clean all with level';

done-testing;
