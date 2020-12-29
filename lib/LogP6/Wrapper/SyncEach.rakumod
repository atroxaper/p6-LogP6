use LogP6::Wrapper;
use LogP6::Wrapper::SyncAbstract;
use LogP6::LogGetter;

#| Wrapper for synchronize a logger each time it use.
class LogP6::Wrapper::SyncEach is LogP6::Wrapper::SyncAbstract {
	method sync($context) {
		self.update-aggr;
	}
}

#| Wrapper logic for synchronize a logger each time it use.
class LogP6::Wrapper::SyncEach::Wrapper
		is LogP6::Wrapper::SyncAbstract::Wrapper {
	#| Method for retrieving the new logger
	has &.get-logger-pure;

	method wrap(LogP6::Wrapper::SyncEach::Wrapper:D:
		LogP6::Logger:D $logger --> LogP6::Logger:D
	) {
		return LogP6::Wrapper::SyncEach.new(
			:aggr($logger),
			:get-fresh-logger(&!get-logger-pure // &get-pure)
		)
	}
}

