use LogP6::Logger;

#| Logic for decorate a logger into another logger.
role LogP6::Wrapper {

	#| Decorate logger.
	method wrap(LogP6::Logger:D $logger --> LogP6::Logger:D) { ... }
}
