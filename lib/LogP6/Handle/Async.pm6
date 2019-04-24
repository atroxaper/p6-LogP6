#|[Async IO::Handle which delegates all WRITE calls to another handle in
#| another threads.]
class LogP6::Handle::Async is IO::Handle {
	has IO::Handle $.delegate is required;
	has Scheduler $.scheduler;

	submethod TWEAK() {
		self.encoding: $!delegate.encoding;
		$!scheduler = $*SCHEDULER without $!scheduler;
	}

	method WRITE(IO::Handle:D: Blob:D \data --> Bool:D) {
		$!scheduler.cue({ $!delegate.WRITE(data) });
		True;
	}

	method close() {
		$!delegate.close;
	}

	method READ(|) { #`[do nothing] }

	method EOF { #`[do nothing] }
}
