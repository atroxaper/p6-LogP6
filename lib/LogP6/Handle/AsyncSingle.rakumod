#|[Async IO::Handle which delegate all WRITE calls to another handle in
#| one separate thread.]
class LogP6::Handle::AsyncSingle is IO::Handle {
	has IO::Handle $.delegate is required;
	has Scheduler $.scheduler;
	has Channel $!queue;
	has Promise $!executor;

	submethod TWEAK() {
		self.encoding: $!delegate.encoding;
		$!scheduler = $*SCHEDULER without $!scheduler;
		$!queue .= new;
		$!executor .= new;
		$!scheduler.cue({
			react {
				whenever $!queue -> \blob {
					$!delegate.WRITE(blob);
				}
			}
			$!executor.keep(True);
		});
	}

	method WRITE(IO::Handle:D: Blob:D \data --> Bool:D) {
		$!queue.send(data) unless $!queue.closed;
		True;
	}

	method close() {
		$!queue.close;
		await $!executor;
		$!delegate.close;
	}

	method READ(|) { #`[do nothing] }

	method EOF { #`[do nothing] }
}