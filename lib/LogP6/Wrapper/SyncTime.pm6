use LogP6::Wrapper;
use LogP6::Wrapper::SyncAbstract;
use LogP6::LogGetter;

class LogP6::Wrapper::SyncTime is LogP6::Wrapper::SyncAbstract {
	has Int:D $.seconds is required;

	method sync($context) {
		$context.date-clean();
		my $last = self.get-sync-obj;
		without $last {
			$last = DateTime.now;
			self.put-sync-obj($last);
		}
		my $now = $context.date;
		if $now - $last > $!seconds {
			self.update-aggr;
			self.put-sync-obj($now);
		}
	}
}

class LogP6::Wrapper::SyncTime::Wrapper
		is LogP6::Wrapper::SyncAbstract::Wrapper
{
	has Int:D $.seconds is required;
	has &.get-logger-pure;

	method wrap(LogP6::Wrapper::SyncTime::Wrapper:D:
		LogP6::Logger:D $logger --> LogP6::Logger:D
	) {
		return LogP6::Wrapper::SyncTime.new(
			:$!seconds, :aggr($logger),
			:get-fresh-logger(&!get-logger-pure // &get-pure)
		)
	}
}
