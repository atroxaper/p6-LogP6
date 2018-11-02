use LogP6::LoggerSyncAbstract;

class LogP6::LoggerSyncTime is LogP6::LoggerAbstractSync {
	has Int:D $.seconds is required;

	method sync($context) {
		my DateTime $last = self.get-sync-obj // DateTime.now;
		my $now = $context.date;
		self.update-aggr if $now - $last > $!seconds;
		say $now - $last;
		self.put-sync-obj($now);
	}
}
