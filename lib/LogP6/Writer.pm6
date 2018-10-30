class LogP6::WriterConf {
	has Str $.name;
	has Str $.pattern is required;
}

class LogP6::Writer {
	has Str:D $.pattern is required;

	only method new(LogP6::WriterConf:D $conf, Str:D $default-pattern) {
		self.bless(
			pattern => $conf.pattern // $default-pattern,
		);
	}

	submethod TWEAK() {

	}
}