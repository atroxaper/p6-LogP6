unit module LogP6::LogGetter;

my &my-get-wrap;
my &my-get-pure;

sub init-getter(:&get-wrap, :&get-pure) is export {
	&my-get-wrap = &get-wrap;
	&my-get-pure = &get-pure;
}

sub get-wrap($trait) is export {
	my-get-wrap($trait);
}

sub get-pure($trait) is export {
	my-get-pure($trait)
}
