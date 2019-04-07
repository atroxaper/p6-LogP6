use Test;

use lib 'lib';
use lib './t/resource/Helpers';
use LogP6 :configure;
use LogP6::Wrapper::SyncEach;
use IOString;

plan 2;

my IOString $h .= new;
writer(:name<writer>, :handle($h), :pattern<%msg>);
filter(:name<filter>, :level($info));

set-default-wrapper(LogP6::Wrapper::SyncEach::Wrapper.new);

subtest {
	plan 4;

	my $cliche =
			cliche(:name<mute-cliche>, :matcher<mute>, grooves => <writer filter>);

	my $logger = get-logger('mute');
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'mute logger worked';

	$cliche = cliche(:name($cliche.name), :matcher($cliche.matcher), :replace);
	$logger.info('this log is dropped already');
	nok $h.clean, 'mute logger is turned off immediately';
	sleep(1);
	$logger.info('ignore this');
	nok $h.clean, 'mute logger is turned off';

	cliche($cliche, :replace);
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'mute logger is turned on immediately';
}, 'mute sync';

subtest {
	plan 4;

	my $cliche = cliche(:name<general-cliche>, :matcher<general>,
			grooves => <writer filter>);

	my $logger = get-logger('general');
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'logger worked';

	filter(:name<filter>, :level($error), :replace);
	$logger.info('this log is not important already');
	nok $h.clean, 'logger is changed level immediately';
	sleep(1);
	$logger.info('ignore this');
	nok $h.clean, 'logger is changed level';

	filter(:name<filter>, :level($info), :replace);
	$logger.info('log this');
	is $h.clean.trim, 'log this', 'logger is changed level back immediately';
}, 'general sync';

done-testing;
