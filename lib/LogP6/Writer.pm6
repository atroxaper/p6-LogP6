# for pattern
# %trait - logger name (trait)
# %date{yyyy-mm-dd hh:mm:ss z} - date and time
# %mdc{key} - mdc-value
# %ndc - ndc-stack
# %x{msg name trace} - exception {message class-name backtrace}
# %msg - message
# %level{WARN=W, DEBUG=D, ERROR=E, TRACE=T, INFO=I, length=2}
# %tname - thread name
# %tid - thread id

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