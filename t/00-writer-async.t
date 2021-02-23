use Test;

use lib 'lib';
use lib './t/resource/Helpers';
use LogP6 :configure;
use IOString;
use LogP6::WriterConf::Async;

plan 2;

my IOString $handle .= new;
my $delegate = writer(:pattern('%msg'), :$handle);
my $async = LogP6::WriterConf::Async.new(:name<async-writer>, :$delegate);
writer($async);
cliche(:name<async>, :matcher<async>,
		grooves => ('async-writer', level($info)));

my $log = get-logger('async');

$log.info('boom');

sleep(1);

is $handle.clean().trim, "boom", 'delegate writes';
$async.close;
ok $handle.closed, 'handle closed';

done-testing;
