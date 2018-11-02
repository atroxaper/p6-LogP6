use Test;

use lib 'lib';
use LogP6 :configure;

$*OUT.out-buffer = False;

writer(name => "w1", pattern => "w1 %msg", handle => $*ERR);
my $writer-w2 = writer(name => "w2", pattern => "w2 %msg");
my $writer-uuid2 = writer();

filter(name => "f1", level => $trace);
my $filter-f2 = filter(name => "f2", level => $debug);
my $filter-uuid1 = filter(level => $info);
my $filter-uuid2 = filter();

cliche(
	name => 'about users', matcher => 'foo t',
	default-level => $info,
	grooves => (
		(writer(pattern => "uuid1 %msg"), $filter-uuid1),
		($writer-uuid2, $filter-uuid2),
		("w1", "f1"),
		($writer-w2, $filter-f2),
		("w1"), "f1"
	)
);

cliche(
	name => 'test writer', matcher => 'writer', default-level => $trace,
	grooves => (
		writer(pattern => '%level{WARN=Wwarn INFO=Iinfo ERROR=Eerror TRACE=Ttrace length=3}|| [%date{$yyyy-$MMM-$dd $hh:$mm:$ss $z}][%tid|%tname](%trait){user=%mdc{user},%ndc} %msg'), ""
	)
);

my $x;
#die "fake exception";
#CATCH { when X::AdHoc { $x = $_; .resume; } }

my $w-logger = get-logger('writer');
$w-logger.info('it works! %s !', 'booo', :$x);
$w-logger.ndc-push('np1');
$w-logger.ndc-push('np2');
$w-logger.mdc-put('user', 'misha');
$w-logger.debug('it works! %s !');
$w-logger.ndc-pop();
$w-logger.debug();

use LogP6::Logger;
my $wr = LogP6::LoggerTimeSync.new(seconds => 5, aggr => $w-logger, get-fresh-logger => &get-logger);
$wr.info('wrapper');

say get-logger("foo t");
writer(name => 'w2', pattern => 'w2 update', :update);
say get-logger("foo t");
say get-logger("default");
my $logger = get-logger("foo t");
$logger.info("this is log msg");
$logger.debug("this is log msg (debug)");

say ">> ", %?RESOURCES;

cliche(name => 'about users', :remove);
$logger = get-logger("foo t");
$logger.info("this is log msg");
$logger.debug("this is log msg (debug)");

done-testing;
