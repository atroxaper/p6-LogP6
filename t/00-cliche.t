use Test;

use lib 'lib';
use LogP6;

writer(name => "w1", pattern => "w1 %s");
my $writer-w2 = writer(name => "w2", pattern => "w2 %s");
my $writer-uuid2 = writer(pattern => "uuid2 %s");

filter(name => "f1", level => 1);
my $filter-f2 = filter(name => "f2", level => 2);
my $filter-uuid1 = filter(level => 3);
my $filter-uuid2 = filter();

cliche(
	name => 'about users', matcher => 'foo t', default-level => 3,
	parts => (
		(writer(pattern => "uuid1 %s"), $filter-uuid1),
		($writer-uuid2, $filter-uuid2),
		("w1", "f1"),
		($writer-w2, $filter-f2),
		("w1"),
		"w1"
	)
);

say get-logger("foo t");

done-testing;
