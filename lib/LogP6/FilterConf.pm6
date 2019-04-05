use LogP6::Filter;

#| Factory object for Writer
role LogP6::FilterConf {
	#| Gets name of configuration. The name will be used as unique identifier.
	method name(--> Str) { ... }

	#|[Clone the configuration with another name. The method is used in case we
	#| want to set or change configuration name.]
	method clone-with-name($name --> LogP6::FilterConf:D) { ... }

	#|[Check a consistency of configuration values. Configuration can be changed
	#| from time to time and can be in non consistency state. The method is used
	#| when we already want to use the configuration to produce a filter.]
	method self-check(--> Nil) { #`[is not a stub] }

	#| Create filter object.
	method make-filter(*%defaults --> LogP6::Filter:D) { ... }
}
