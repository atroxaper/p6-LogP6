use LogP6::Writer;

role LogP6::WriterConf {
	method name() { ... }
	method clone-with-name($name) { ... }
	method self-check() { ... }
	method make-writer(*%defaults --> LogP6::Writer:D) { ... }
	method close() { ... }
}