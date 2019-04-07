use Test;

use lib 'lib';
use lib './t/resource/Helpers';
use LogP6 :configure;
use LogP6::Wrapper::SyncTime;
use IOString;

plan 3;

my IOString $h .= new;
writer(:name<writer>, :handle($h), :pattern<%msg>);
filter(:name<filter>, :level($info));

set-default-wrapper(
	LogP6::Wrapper::SyncTime::Wrapper.new(:2seconds));

subtest {
	plan 3;

	my $cliche =
			cliche(:name<mute-cliche>, :matcher<mute>, grooves => <writer filter>);

	my $logger = get-logger('mute');
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'mute logger worked';

	$cliche = cliche(:name($cliche.name), :matcher($cliche.matcher), :replace);
	$logger.info('log this yet');
	sleep(3);
	$logger.info('ignore this');
	is $h.clean, "log this yet\n", 'mute logger is turned off';

	cliche(:name($cliche.name), :matcher($cliche.matcher),
					grooves => <writer filter>, :replace);
	sleep(3);
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'mute logger worked again';
}, 'mute sync';

subtest {
	plan 3;

	my $cliche = cliche(:name<general-cliche>, :matcher<general>,
			grooves => <writer filter>);

	my $logger = get-logger('general');
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'general logger worked';

	filter(:name<filter>, :level($error), :replace);
	$logger.info('log this yet');
	sleep(3);
	$logger.info('ignore this');
	is $h.clean, "log this yet\n", 'general logger is changed level';

	filter(:name<filter>, :level($info), :replace);
	sleep(3);
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'general logger worked again';
}, 'general sync';

subtest {
	plan 1;

	my $cliche =
			cliche(:name<first-sync>, :matcher<first>, grooves => <writer filter>);

	my $loggger = get-logger('first');
	filter(:name<filter>, :level($warn), :replace);
	$loggger.info('dropped');

	nok $h.clean, 'sync logger before its first use';
}, 'first sync';

done-testing;
