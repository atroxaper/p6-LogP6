use LogP6::Level;

role LogP6::Filter {
	#|[Log level which allows logger to call do-before method. If log level
	#| importance is less then reactive level then the log will be discarded
	#| without calling do-before method. Default value is 'trace'.
	#|
	#| Note: the method can be called only ones and the result can be cached
	#| in the logger.]
	method reactive-level() { #`[is not a stub] }

	#|[Decide allow log to be pass to the writer or not. If it returns True then
	#| the log will be pass to the writer. Otherwise the log will be discarded.]
	method do-before($context) { ... }

	#|[Any code which have to be executed after the writer work in case when
	#| do-before method returns True.]
	method do-after($context) { #`[is not a stub] }
}