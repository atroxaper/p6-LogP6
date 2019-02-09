use Test;

use lib 'lib';
use LogP6::Cliche;
use LogP6::Wrapper::Transparent;
use LogP6 :configure;

plan 20;

my LogP6::Cliche $cliche = LogP6::Cliche.new(
		:name<n>, :matcher<*>, :default-level($trace), :default-pattern<ptrn>,
		:wrapper(LogP6::Wrapper::Transparent::Wrapper.new),
		writers => <w1 w2>, filters => <f1 f2>
);

dies-ok { $cliche.has('w1', 'what') }, 'only writer or filter can be serched';
ok $cliche.has('w1', 'writer'), 'has w1';
ok $cliche.has('w2', 'writer'), 'has w2';
ok $cliche.has('f1', 'filter'), 'has f1';
ok $cliche.has('f2', 'filter'), 'has f2';
nok $cliche.has('w3', 'writer'), 'do not has w3';
nok $cliche.has('f3', 'filter'), 'do not has f3';
ok $cliche.wrapper, 'has wrapper';
does-ok $cliche.wrapper, LogP6::Wrapper::Transparent::Wrapper,
		'has transparent wrapper';

dies-ok { $cliche.copy-with-new('w1', 'w3', 'what') },
		'only writer or filter can be chnaged';

my $cliche-w3 = $cliche.copy-with-new('w1', 'w3', 'writer');
isnt $cliche, $cliche-w3, 'copy cliche is another cliche';
is-deeply $cliche-w3.writers, <w3 w2>, 'copy writers';
is-deeply $cliche-w3.filters, <f1 f2>, 'copy filters';
is $cliche-w3.name, $cliche.name, 'copy has the same name';
is $cliche-w3.matcher, $cliche.matcher, 'copy has the same matcher';
is $cliche-w3.default-level, $cliche.default-level, 'copy has the same level';
is $cliche-w3.default-pattern, $cliche.default-pattern,
		'copy has the same pattern';

my $cliche-f3 = $cliche-w3.copy-with-new('f2', 'f3', 'filter');
isnt $cliche-f3, $cliche-w3, 'another copy cliche is another cliche';
is-deeply $cliche-f3.writers, <w3 w2>, 'another copy writers';
is-deeply $cliche-f3.filters, <f1 f3>, 'another copy filters';

done-testing;
