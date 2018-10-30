class LogP6::WriterConf {
	has Str $.name;
	has Str $.pattern;
	has IO::Handle $.handle;
}

class LogP6::Writer {
	has Str:D $.pattern is required;
	has IO::Handle:D $.handle is required;

	only method new(LogP6::WriterConf:D $conf, Str:D $default-pattern) {
		self.bless(
			pattern => $conf.pattern // $default-pattern,
			handle => $conf.handle // $*OUT
		);
	}

	submethod TWEAK() {

	}

	method write($context) {
		$!handle.say(
				$context.level-get, ' - ',
				$context.date-get, ' - ',
				$context.msg-get, ' - ',
				$!pattern
		);
	}
}