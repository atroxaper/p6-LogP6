use LogP6::WriterConf;
use LogP6::Writer::Async;

#| Conf for Async writer which delegates writing to another writer in another
#| threads.
class LogP6::WriterConf::Async does LogP6::WriterConf {
	has LogP6::WriterConf $.delegate is required;
	has Str $.name;
	has Scheduler $.scheduler;
	has Bool $.need-callframe;

	submethod TWEAK() {
		$!name = $!delegate.name without $!name;
	}

	method clone-with-name($name --> LogP6::WriterConf:D) {
		return self.close: :$name;
	}

	method make-writer(*%defaults --> LogP6::Writer:D) {
		LogP6::Writer::Async.new(
			:delegate($!delegate.make-writer(|%defaults)),
			:scheduler($!scheduler // $*SCHEDULER),
			:$!need-callframe
		);
	}

	method name(--> Str) {
		$!name;
	}

	method close(--> Nil) {
		$!delegate.close;
	}
}
