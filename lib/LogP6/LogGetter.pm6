#|[Module with subs for getting wrapped and pure logger.
#| The modules are created for avoid circular dependencies
#| (many modules depends on LogP6 module).
unit module LogP6::LogGetter;

my &my-get-wrap;
my &my-get-pure;

#| Sets subs for getting wrapped and pure loggers.
sub init-getter(:&get-wrap, :&get-pure) is export {
	&my-get-wrap = &get-wrap;
	&my-get-pure = &get-pure;
}

#| Gets wrapped logger.
sub get-wrap($trait) is export {
	my-get-wrap($trait);
}

#| Gets pure logger.
sub get-pure($trait) is export {
	my-get-pure($trait)
}
