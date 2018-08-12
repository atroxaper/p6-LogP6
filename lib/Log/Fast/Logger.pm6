class Log::Fast::Logger {
	has Str:D $.regex is required;
	has Str:D $.name;
	has Positional $.entry;

	method debug(Log::Fast::Logger:D:) {

	}

	method minus-writers($writers) {
		return self without $writers;
		my List $new-writers;
		if $writers ~~ Positional {
			$new-writers = $!writers (-) $writers;
		} else {
			$new-writers = $!writers (-) ($writers).List;
		}
		return self.clone(writers => $new-writers);
	}
}

sub EXPORT($short-name?) {
	%(do $short-name => Log::Fast::Logger if $short-name)
}