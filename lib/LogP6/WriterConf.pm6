use LogP6::Writer;

role LogP6::WriterConf {
	method name() { ... }
	method clone-with-name($name) { ... }
	method self-check() { #`[is not a stub] }
	method make-writer(--> LogP6::Writer:D) { ... }
	method close() { ... }
}