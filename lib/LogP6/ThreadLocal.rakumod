use LogP6::Context;

#|[Role with LogP6::Context filed.
#| Used for adding LogP6::Context into Thread object.]
role LogP6::ThreadLocal {
	has $._context = LogP6::Context.new;
}