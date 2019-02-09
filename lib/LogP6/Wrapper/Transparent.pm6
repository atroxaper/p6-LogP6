use LogP6::Wrapper;

class LogP6::Wrapper::Transparent::Wrapper does LogP6::Wrapper {
	method wrap(LogP6::Logger:D $logger --> LogP6::Logger:D) {
		$logger;
	}
}
