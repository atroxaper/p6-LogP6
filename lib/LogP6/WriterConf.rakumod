use LogP6::Writer;

#| Factory object for Writer
role LogP6::WriterConf {
	#| Gets name of configuration. The name will be used as unique identifier.
	method name(--> Str) { ... }

	#|[Clone the configuration with another name. The method is used in case we
	#| want to set or change configuration name.]
	method clone-with-name($name --> LogP6::WriterConf:D) { ... }

	#|[Check a consistency of configuration values. Configuration can be changed
	#| from time to time and can be in non consistency state. The method is used
	#| when we already want to use the configuration to produce a writer.]
	method self-check(--> Nil) { #`[is not a stub] }

	#| Create writer object.
	method make-writer(--> LogP6::Writer:D) { ... }

	#|[Close any resources the factory need. Since the writers are created from
	#| the one factory, the factory have to be know about all resources it
	#| opened.]
	method close(--> Nil) { ... }
}