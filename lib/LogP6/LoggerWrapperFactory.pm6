use LogP6::Logger;

role LogP6::LoggerWrapperFactory {
	method wrap(LogP6::Logger:D $logger --> LogP6::Logger:D) { ... }
}
