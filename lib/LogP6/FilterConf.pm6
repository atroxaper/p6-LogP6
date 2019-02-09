use LogP6::Filter;

role LogP6::FilterConf {
	method name() { ... }
	method clone-with-name($name) { ... }
	method self-check() { ... }
	method make-filter(*%defaults --> LogP6::Filter:D) { ... }
}
