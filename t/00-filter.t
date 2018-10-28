use Test;

use lib 'lib';
use LogP6;

# create and store with name
my $created = filter(:name<first>, :level(3), :create);
my $first-filter = get-filter('first');

isa-ok $first-filter, LogP6::FilterConf, 'get first filter';
ok $first-filter.defined, 'first filter defined';
is $first-filter.level, 3, 'filters level saved';
is $created, $first-filter, 'builder and getter return the same';

# create without name (do not store)
my $second-filter = filter(:level(1), :create);

is $second-filter.name, Str, 'create filter w/o name';
is $second-filter.level, 1, 'w/o name but with level';

done-testing;
