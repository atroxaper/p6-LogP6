use LogP6::Writer;
use LogP6::WriterConf;
use LogP6::WriterConf::Pattern;

class LogP6::Writer::Std does LogP6::Writer {
	has Str:D $.pattern is required;
	has IO::Handle:D $.handle is required;

	has @!pieces;

	only method new(LogP6::WriterConf:D $conf, *%defaults) {
		my $auto-exeptions = $conf.auto-exceptions // True;
		my $pattern = $conf.pattern // %defaults<default-pattern>;
		$pattern ~= %defaults<default-x-pattern> if $auto-exeptions;
		self.bless(
			pattern => $pattern,
			handle => $conf.handle // %defaults<default-handle>
		);
	}

	submethod TWEAK() {
		@!pieces := Grammar.parse($!pattern, actions => Actions).made;
	}

	method write($context) {
		$!handle.say(|@!pieces>>.show($context));
	}
}