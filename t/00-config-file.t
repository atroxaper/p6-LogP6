use Test;

use lib 'lib';
use LogP6 :configure;

use lib 't/resource/00-config-file';

init-from-file('./t/resource/00-config-file/log-p6.json');

END {
	for 't/resource/00-config-file'.IO.dir() -> $_ {
		.unlink if .ends-with('.after');
	}
}

done-testing;
