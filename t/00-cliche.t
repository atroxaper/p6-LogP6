use Test;

use lib 'lib';
use LogP6 :configure;

$*OUT.out-buffer = False;

writer(name => "w1", pattern => "w1 %s", handle => $*ERR);
my $writer-w2 = writer(name => "w2", pattern => "w2 %s");
my $writer-uuid2 = writer();

filter(name => "f1", level => $trace);
my $filter-f2 = filter(name => "f2", level => $debug);
my $filter-uuid1 = filter(level => $info);
my $filter-uuid2 = filter();

cliche(
	name => 'about users', matcher => 'foo t',
	default-level => $info,
	grooves => (
		(writer(pattern => "uuid1 %s"), $filter-uuid1),
		($writer-uuid2, $filter-uuid2),
		("w1", "f1"),
		($writer-w2, $filter-f2),
		("w1"), "f1"
	)
);

cliche(
	name => 'test writer', matcher => 'writer',
	grooves => (
		writer(pattern => '[%tid|%tname](%trait){user=%mdc{user},%ndc} %msg'), ""
	)
);

my $w-logger = get-logger('writer');
$w-logger.info("it works!");

#say get-logger("foo t");
writer(name => 'w2', pattern => 'w2 update', :update);
#say get-logger("foo t");
#say get-logger("default");
#say $?MODULE;
#my $logger = get-logger("foo t");
#$logger.info("this is log msg");
#$logger.debug("this is log msg (debug)");

done-testing;
