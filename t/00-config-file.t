use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::ConfigFile;
use lib './t/resource/Helpers';
use IOString;

plan 8;

$*ERR = IOString.new;
my LogP6::ConfigFile $config .= new;

subtest {
	plan 1;

	lives-ok { init-from-file('./t/resource/00-config-file/log-p6-empty.json') },
		'cannot init from empty file';

}, 'empty file';

subtest {
	plan 2;

	lives-ok { init-from-file('./t/resource/00-config-file/not-exist.json') },
		'cannot init from miss file';
	lives-ok { init-from-file(Any) }, 'can init empty argument';

}, 'miss file';

subtest {
	plan 23;

	CATCH { default {say .gist }}

	my ($w, $cn);
	$cn = $config.parse-config('./t/resource/00-config-file/log-p6-1.json');

	is $cn.writers.elems, 6, 'parsed 5 writers';

	$w = $cn.writers[0];
	is $w.name, 'w1', 'w1 name';
	is $w.pattern, '%msg', 'w1 pattern';
	is $w.handle.Str, './t/resource/00-config-file/handle1.after', 'w1 handle';
	is $w.handle.out-buffer, 0, 'w1 out-buffer false(0)';
	ok $w.auto-exceptions, 'w1 auto-exceptions';

	$w = $cn.writers[1];
	is $w.name, 'w2', 'w2 name';
	is $w.pattern, '%level | %msg', 'w2 pattern';
	is $w.handle, $*OUT, 'w2 handle';
	is $w.handle.out-buffer, 100, 'w2 out-buffer false(0)';
	is $cn.writers[2].handle, $*ERR, 'w3 handle';
	nok $w.auto-exceptions, 'w2 auto-exceptions';

	$w = $cn.writers[3];
	is $w.name, 'w4', 'w4 name';
	nok $w.pattern, 'w4 pattern';
	is $w.handle.Str, './t/resource/00-config-file/handle2.after', 'w4 handle';
	nok $w.auto-exceptions, 'w4 auto-exceptions';

	$w = $cn.writers[4];
	is $w.name, 'w5', 'w5 name';
	nok $w.pattern, 'w5 pattern';
	nok $w.handle, 'w5 handle';
	nok $w.auto-exceptions, 'w5 auto-exceptions';

	$w = $cn.writers[5];
	is $w.handle.out-buffer, 1000, 'w6 handle out-buffer 1000';

	my $w0h = $cn.writers[0].handle.WHICH;
	my $w3h = $cn.writers[3].handle.WHICH;
	$cn = $config.parse-config('./t/resource/00-config-file/log-p6-1.json');
	is $w0h, $cn.writers[0].handle.WHICH, 'get file handle from cache';
	is $w3h, $cn.writers[3].handle.WHICH, 'get custom handle from cache';

}, 'writers';

subtest {
	plan 21;

	use lib './t/resource/Helpers';
	use lib './t/resource/00-config-file';
	use Custom;

	my ($f, $cn);
	$cn = $config.parse-config('./t/resource/00-config-file/log-p6-1.json');

	is $cn.filters.elems, 4, 'parsed 4 writers';

	$f = $cn.filters[0];
	is $f.name, 'f1', 'f1 name';
	is $f.level, $error, 'f1 level';
	nok $f.first-level-check, 'f1 first-level-check';
	is-deeply $f.before-check, (before-check1(),), 'f1 before';
	is-deeply $f.after-check, (), 'f1 after';

	$f = $cn.filters[1];
	is $f.name, 'f2', 'f2 name';
	is $f.level, $warn, 'f2 level';
	ok $f.first-level-check, 'f2 first-level-check';
	is-deeply $f.before-check, (before-check1(), before-check2()), 'f2 before';
	is-deeply $f.after-check, (after-check(),), 'f2 after';

	$f = $cn.filters[2];
	is $f.name, 'f3', 'f3 name';
	nok $f.level, 'f3 level';
	nok $f.first-level-check, 'f3 first-level-check';
	nok $f.before-check, 'f3 before';
	nok $f.after-check, 'f3 after';

	$f = $cn.filters[3];
	is $f.name, 'f4', 'f4 name';
	nok $f.level, 'f4 level';
	nok $f.first-level-check, 'f4 first-level-check';
	nok $f.before-check, 'f4 before';
	nok $f.after-check, 'f4 after';

}, 'filters';

subtest {
	plan 23;

	use LogP6::Wrapper::Transparent;

	my ($c, $cn);
	$cn = $config.parse-config('./t/resource/00-config-file/log-p6-1.json');

	is $cn.cliches.elems, 2, 'parsed 2 cliches';

	$c = $cn.cliches[0];
	is $c.name, 'c1', 'c1 name';
	ok $c.matcher ~~ Regex, 'c1 matcher';
	ok 'bo__om' ~~ $c.matcher, 'c1 matcher works';
	is $c.default-pattern, '%level %msg', 'c1 default-parren';
	ok $c.default-auto-exceptions, 'c1 default-auto-exceptions';
	is $c.default-handle, $*OUT, 'c1 default-handle';
	is $c.default-x-pattern, '%x{$msg}', 'c1 default-x-pattern';
	is $c.default-level, $info, 'c1 default-level';
	nok $c.default-first-level-check, 'c1 default-first-level-check';
	is-deeply $c.grooves, <w1 f1 w2 f1>, 'c1 grooves';
	does-ok $c.wrapper, LogP6::Wrapper::Transparent::Wrapper, 'c1 wrapper';

	$c = $cn.cliches[1];
	is $c.name, 'c2', 'c2 name';
	ok $c.matcher ~~ Str, 'c2 matcher';
	ok 'boom/' ~~ $c.matcher, 'c2 matcher works';
	nok $c.default-pattern, 'c2 default-parren';
	nok $c.default-auto-exceptions, 'c2 default-auto-exceptions';
	nok $c.default-handle, 'c2 default-handle';
	nok $c.default-x-pattern, 'c2 default-x-pattern';
	nok $c.default-level, 'c2 default-level';
	nok $c.default-first-level-check, 'c2 default-first-level-check';
	is-deeply $c.grooves, (), 'c2 grooves';
	nok $c.wrapper, 'c2 wrapper';

}, 'cliches';

subtest {
	plan 8;

	use LogP6::Wrapper::SyncTime;

	my $cn = $config.parse-config('./t/resource/00-config-file/log-p6-1.json');
	is $cn.default-pattern, '%msg', 'default-pattern';
	is $cn.default-auto-exceptions, False, 'default-auto-exceptions';
	is $cn.default-handle, $*ERR, 'default-handle';
	is $cn.default-x-pattern, "%x\n%x\a%x\e%x", 'default-x-pattern';
	is $cn.default-level, $trace, 'default-level';
	is $cn.default-first-level-check, True, 'default-first-level-check';
	ok $cn.default-wrapper, 'default-wrapper ok';
	does-ok $cn.default-wrapper, LogP6::Wrapper::SyncTime::Wrapper,
			'default-wrapper does';

}, 'defaults';

subtest {
	plan 6;

	use lib './t/resource/Helpers';
	use lib './t/resource/00-config-file';
	use Custom;
	use LogP6::Wrapper::SyncEach;

	my $x;
	{
		die 'test ex';
		CATCH { default { $x = $_; .resume } }
	}

	init-from-file('./t/resource/00-config-file/log-p6-2.json');

	my $log = get-logger('log');
	$log.trace('logtrace', :$x);
	$log.debug('logdebug', :$x);

	my $gol = get-logger('gol');
	$gol.trace('goltrace', :$x);
	$gol.debug('goldebug', :$x);

	my $default-io = io-string(:name<default>);
	my $cliche-io = io-string(:name<cliche>);

	ok defined($default-io), 'default io ok';
	is $default-io.writed.trim, 'logdebug test ex', 'defaults ok';
	ok defined($cliche-io), 'cliche io ok';
	is $cliche-io.writed.trim, "goltrace X::AdHoc\ngoldebug X::AdHoc",
			'cliche ok';

	my $wrapper = get-cliche('c2').wrapper;
	does-ok $wrapper, LogP6::Wrapper::SyncEach::Wrapper, 'each wrapper parced';
	is $wrapper.config-path, './t/resource/00-config-file/log-p6-2.json',
			'each wrapper parced config-path';
}, 'integration defaults';

subtest {
	plan 11;

	use lib './t/resource/Helpers';
	use lib './t/resource/00-config-file';
	use LogP6::FilterConf::Std;
	use LogP6::WriterConf::Std;
	use Custom;

	init-from-file('./t/resource/00-config-file/log-p6-2.json');

	my $wrapper = get-cliche('c1').wrapper;

	ok $wrapper, 'custom args wrapper ok';
	does-ok $wrapper, LogP6::Wrapper::Custom, 'custom args does ok';
	is $wrapper.name, 'args-name', 'custom args field';
	does-ok $wrapper.arr, Positional, 'custom args arr positional';
	is $wrapper.arr.elems, 2, 'custom args arr elems';
	is $wrapper.arr[0], 'arr-element', 'custom args arr first field';
	does-ok $wrapper.arr[1], LogP6::FilterConf::Std,
			'custom args arr second custom does';
	is $wrapper.arr[1].name, 'arr-filter',
			'custom args arr second custom name';
	does-ok $wrapper.custom, LogP6::WriterConf::Std,
			'custom args custom does';
	is $wrapper.custom.name, 'args-writer', 'custom args custom name';
	is-deeply $wrapper.map, %(:a<b>, :x<y>), 'custom args map ok';

}, 'agrs in custom';

END {
	for 't/resource/00-config-file'.IO.dir() -> $_ {
		.unlink if .ends-with('.after');
	}
}

done-testing;
