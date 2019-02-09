use LogP6::Level;

role LogP6::Filter {
	method reactive-check($level) { ... }
	method do-before($context) { ... }
	method do-after($context) { ... }
}