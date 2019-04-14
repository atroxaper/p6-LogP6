use Test;

use lib 'lib';
use LogP6 :configure;
use LogP6::ConfigFile;
use lib './t/resource/Helpers';
use IOString;

plan 3;

$*ERR = IOString.new;

lives-ok {
	init-from-file('./t/resource/00-config-file/log-p6-wrong-syntax.json') },
	'cannot init from wrong syntax file';
lives-ok {
	init-from-file('./t/resource/00-config-file/log-p6-corrupt.json') },
	'cannot init from corrupt file';
lives-ok {
	init-from-file('./t/resource/00-config-file/log-p6-wrong-config.json') },
	'cannot init from corrupt file';

done-testing;
