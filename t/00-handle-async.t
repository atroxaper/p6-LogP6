use Test;

use lib 'lib';
use LogP6::Handle::Async;
use lib './t/resource/Helpers';
use IOString;

plan 2;

my IOString $delegate .= new;
my LogP6::Handle::Async $async .= new: :$delegate;

$async.say('boom');
$async.say('moob');
sleep(1);

is $delegate.clean.lines.List, ("boom", "moob"), 'delegate writes';

$async.close;
ok $delegate.closed, 'delegate closed';

done-testing;
