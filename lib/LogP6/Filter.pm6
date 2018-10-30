use LogP6::Level;

class LogP6::FilterConf {
	has Str $.name;
	has LogP6::Level $.level;
}

class LogP6::Filter {
	has LogP6::Level:D $.level is required;

	only method new(LogP6::FilterConf:D $conf, LogP6::Level:D $default-level) {
		self.bless(
			level => $conf.level // $default-level,
		);
	}

	submethod TWEAK() {

	}
}