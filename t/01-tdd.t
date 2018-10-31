use Test;

use lib 'lib';

use Grammar::Tracer;


say Gr.parse('%level{WARN = W DEBUG=   D ERROR=E TRACE=T INFO=I length=2   } Troom boom %trait [%ndc%ndc]');



done-testing;
