use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::Helpers::IOString;
use LogP6::Helpers::LoggerWrapperSyncTime;

plan 3;

my LogP6::Helpers::IOString $h .= new;
writer(:name<writer>, :handle($h), :pattern<%msg>);
filter(:name<filter>, :level($info));

set-wrapper-factory(
	LogP6::Helpers::LoggerWrapperFactorySyncTime.new(:2seconds));
my $cliche = cliche(:name<cliche>, :matcher<main>, grooves => <writer filter>);

my $logger = get-logger('main');
$logger.info('log this');
is $h.clean.trim, 'log this', 'main logger worked';

$cliche = cliche(:name($cliche.name), :matcher($cliche.matcher), :replace);
$logger.info('log this yet');
sleep(3);
$logger.info('ignore this');
is $h.clean, "log this yet\n", 'main logger is turned off';

cliche(:name($cliche.name), :matcher($cliche.matcher),
	grooves => <writer filter>, :replace);
sleep(3);
$logger.info('log this');
is $h.clean.trim, 'log this', 'main logger worked again';

done-testing;
