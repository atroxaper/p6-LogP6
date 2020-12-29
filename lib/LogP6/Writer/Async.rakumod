use LogP6::Writer;

#| Async writer which delegates writing to another writer in another threads
class LogP6::Writer::Async does LogP6::Writer {
	has LogP6::Writer $.delegate is required;
	has Scheduler $.scheduler is required;
	has Bool $.need-callframe is required;

	method write($context) {
		# initialize date and callframe before copy context
		$context.date();
		$context.callframe() if $!need-callframe;
		my $copy = $context.copy;
		$!scheduler.cue({ $!delegate.write($copy) });
	}
}