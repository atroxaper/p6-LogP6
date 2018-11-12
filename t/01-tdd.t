use Test;

use lib 'lib';

use LogP6::Pattern;

#use Grammar::Tracer;
#say LogP6::Pattern::Grammar.parse(
#		'[$tid|%tname](%trait){user=%mdc{user},%ndc} %msg',
#		actions => LogP6::Pattern::Actions
#).made;

#sub trait_mod:<is>() {*}

class Boo {
	has $.ha;
	has $!ho;
}

say Boo.^methods;
my $meth = method () { say 'the new method'; }
say Boo.^add_method('the-new', $meth);
say Boo.^methods;
Boo.the-new();

say Boo.^attributes;

done-testing;
