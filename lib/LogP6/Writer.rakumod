#| Writer of some data from the context to some output.
role LogP6::Writer {

	#|[Write data from specified context to some output.
	#|
	#| Note: the specified context will change its data after method call. Do not
	#| cache the context itself (for example for asynchronous writing) but only
	#| its data.]
	method write($context) { ... }
}