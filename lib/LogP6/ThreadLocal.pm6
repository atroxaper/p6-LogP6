use LogP6::Context;

role LogP6::ThreadLocal {
	has $._context = LogP6::Context.new;
}