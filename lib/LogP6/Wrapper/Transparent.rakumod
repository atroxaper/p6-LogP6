use LogP6::Wrapper;

#| Logger wrapper which do not wrap a logger.
class LogP6::Wrapper::Transparent::Wrapper does LogP6::Wrapper {
	method wrap(LogP6::Logger:D $logger --> LogP6::Logger:D) {
		$logger;
	}
}
