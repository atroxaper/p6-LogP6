use Test;

use lib 'lib';
use LogP6::Handle::AsyncSingle;
use lib './t/resource/Helpers';
use IOString;

plan 2;

my IOString $delegate .= new;
my LogP6::Handle::AsyncSingle $async .= new: :$delegate;

$async.say('boom');
$async.say('moob');
sleep(1);

is $delegate.clean, "boom\nmoob\n", 'delegate writes';

$async.close;
ok $delegate.closed, 'delegate closed';

done-testing;
