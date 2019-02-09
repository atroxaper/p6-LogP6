use LogP6::LoggerWrapperFactory;
use LogP6::Helpers::LoggerWrapperSyncAbstract;
use LogP6::LogGetter;

class LogP6::Helpers::LoggerWrapperSyncTime
		is LogP6::Helpers::LoggerWrapperSyncAbstract {
	has Int:D $.seconds is required;

	method sync($context) {
		my DateTime $last = self.get-sync-obj // DateTime.now;
		my $now = $context.date;
		self.update-aggr if $now - $last > $!seconds;
		self.put-sync-obj($now);
	}
}

class LogP6::Helpers::LoggerWrapperFactorySyncTime does LogP6::LoggerWrapperFactory {
	has Int:D $.seconds is required;
	has &.get-logger-pure;

	method wrap(LogP6::Helpers::LoggerWrapperFactorySyncTime:D:
		LogP6::Logger:D $logger --> LogP6::Logger:D
	) {
		return LogP6::Helpers::LoggerWrapperSyncTime.new(
			:$!seconds, :aggr($logger),
			:get-fresh-logger(&!get-logger-pure // &get-pure)
		)
	}
}
