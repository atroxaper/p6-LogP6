use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::Context;
use LogP6::Helpers::IOString;

plan 5;

my LogP6::Context $context .= new;
$context.level-set($info);
$context.msg-set("test message");
$context.date-set(DateTime.new(:year(2018), :month(11), :day(3),
		:hour(23), :minute(54), :second(9)));
{
	die 'test exception';
	CATCH { default { $context.x-set: $_; .resume } }
}

my $simple-pattern = '[%date{$hh:$mm:$ss}][%level{length=5}] %msg';
my $default-pattern = '%level| %msg';
my $default-x-pattern = " \%x\{Exception \$name: \$msg\n\$trace}";

my class IO::Fake::Close is IO::Handle {
	has $.closed = False;
	method close() {
		$!closed = True;
	}
}

subtest {
	plan 8;

	my $w-with-name = writer(:name<w-name>, :!auto-exceptions, :handle($*OUT),
			:pattern($simple-pattern));

	my $w-get = get-writer('w-name');
	ok $w-get ~~ LogP6::WriterConfStd:D, 'get defined';
	is $w-get.name, 'w-name', 'right name';
	is $w-get.handle, $*OUT, 'right handle';
	is $w-get.auto-exceptions, False, 'right auto-exceptions';
	is $w-get.pattern, $simple-pattern, 'right auto-exceptions';
	is $w-with-name, $w-get, 'from factory and from get are the same';

	my $w-get-empty = get-writer('not-exitst');
	ok $w-get-empty ~~ LogP6::WriterConf:U, 'get not exist as undefined conf';
	isnt $w-with-name, $w-get-empty, 'from factory and empty are not the same';
}, 'create named writer configuration by factory';

subtest {
	plan 6;

	my $w-with-name = get-writer('w-name');
	my $anothre-name = $w-with-name.clone-with-name('another');
	is $w-with-name.name, 'w-name', 'source has origin name';
	is $anothre-name.name, 'another', 'clone has another name';
	is $w-with-name.pattern, $anothre-name.pattern, 'both have the same level';
	is $w-with-name.auto-exceptions, $anothre-name.auto-exceptions,
			'both have the same auto-exceptions';
	is $w-with-name.handle, $anothre-name.handle, 'both have the same handle';
	isnt $w-with-name.WHICH, $anothre-name.WHICH, 'WHICHes are not the same';
}, 'clone writer configuration';

subtest {
	plan 3;

	my $w-with-name = get-writer('w-name');
	lives-ok { $w-with-name.self-check }, 'writer configuration self check pass';
	lives-ok { writer(:name<empty-pattern>).self-check },
			'self check pass with empty pattern';
	dies-ok { writer(:name<wrong-pattern>, pattern => '%MSG').self-check },
			'writer configuration has wrong pattern';
}, 'self-check writer configuration';

subtest {
	plan 4;

	writer(:handle($*OUT)).close();
	ok $*OUT.opened, '$*OUT are not closeble';
	writer(:handle($*ERR)).close();
	ok $*ERR.opened, '$*ERR are not closeble';
	my IO::Fake::Close $io-fake .= new;
	nok $io-fake.closed, 'fake io is not closed yet';
	writer(:handle($io-fake)).close();
	ok $io-fake.closed, 'fake io is closed now';
}, 'close writer configuration';

subtest {
	plan 9;

	my LogP6::Helpers::IOString $io-str .= new;

	ok get-writer('w-name').make-writer(:$default-pattern)
			~~ LogP6::WriterStd:D, 'make writer proper value';

	my $full = writer(
			:name<full>,
			:!auto-exceptions,
			:handle($io-str),
			:pattern($simple-pattern))
			.make-writer(:$default-pattern);
	is $full.pattern, $simple-pattern, 'make full writer with self pattern';
	is $full.handle.WHICH, $io-str.WHICH, 'make full writer with self handle';

	my $half = writer(:name<half>, :pattern($simple-pattern))
			.make-writer(:$default-pattern);
	is $half.pattern, $simple-pattern ~ $default-x-pattern,
			'make half writer with self pattern plus auto-exceptions';
	is $half.handle, $*OUT, 'make half writer with default handle';

	my $empty = writer(:name<empty>).make-writer(:$default-pattern);
	is $empty.pattern, $default-pattern ~ $default-x-pattern,
			'make empty writer with default pattern plus auto-exceptions';
	is $empty.handle, $*OUT, 'make empty writer with default handle';

	writer(:handle($io-str), :pattern($simple-pattern))
			.make-writer(:$default-pattern)
			.write($context);
	my $result = $io-str.Str.lines.grep(*.chars != 0).List;
	is $result.elems, 2, 'writer produce two lines';
	is $result[0],
			'[23:54:09][INFO ] test message Exception X::AdHoc: test exception',
			'wroter produce correct main line';
}, 'make and use writer';

done-testing;
