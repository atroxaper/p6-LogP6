use LogP6::Pattern;

class LogP6::WriterConf {
	has Str $.name;
	has Str $.pattern;
	has IO::Handle $.handle;
	has Bool $.auto-exceptions;
}

class LogP6::Writer {
	has Str:D $.pattern is required;
	has IO::Handle:D $.handle is required;

	has @!pieces;

	my $default-x = " \%x\{Exception \$name: \$msg\n\$trace}";

	only method new(LogP6::WriterConf:D $conf, Str:D $default-pattern) {
		my $auto-exeptions = $conf.auto-exceptions // True;
		my $pattern = $conf.pattern // $default-pattern;
		$pattern ~= $default-x if $auto-exeptions;
		self.bless(
			pattern => $pattern,
			handle => $conf.handle // $*OUT
		);
	}

	submethod TWEAK() {
		@!pieces := Grammar.parse($!pattern, actions => Actions).made;
	}

	method write($context) {
		$!handle.say(|@!pieces>>.show($context));
	}
}