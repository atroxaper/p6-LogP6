use Test;

use lib 'lib';
use LogP6;

# create and store with name
my $created = writer(:name<first>, :pattern('pat'), :create);
my $first-writer = get-writer('first');

isa-ok $first-writer, LogP6::WriterConf, 'get first writer';
ok $first-writer.defined, 'first writer defined';
is $first-writer.pattern, 'pat', 'writers level saved';
is $created, $first-writer, 'builder and getter return the same';

# create without name (do not store)
my $second-writer = writer(:pattern('tap'), :create);

is $second-writer.name, Str, 'create writer w/o name';
is $second-writer.pattern, 'tap', 'w/o name but with level';

done-testing;
