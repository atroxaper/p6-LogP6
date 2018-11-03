use LogP6::Pattern;

role LogP6::Writer {
	method write($context) { ... }
}

role LogP6::WriterConf {
	method clone-with-name($name) { ... }
	method self-check() { ... }
	method make-writer(*%defaults --> LogP6::Writer:D) { ... }
	method close() { ... }
}

class LogP6::WriterConfStd { ... }

class LogP6::WriterStd does LogP6::Writer {
	has Str:D $.pattern is required;
	has IO::Handle:D $.handle is required;

	has @!pieces;

	only method new(LogP6::WriterConfStd:D $conf, *%defaults) {
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

class LogP6::WriterConfStd does LogP6::WriterConf {
	has Str $.name;
	has Str $.pattern;
	has IO::Handle $.handle;
	has Bool $.auto-exceptions;

	my $default-handle = $*OUT;
	my $default-x-pattern = ' %x{Exception $name: $msg' ~ "\n" ~'$trace}';

	method clone-with-name($name) {
		self.clone(:$name);
	}

	method self-check() {
		return True without $!pattern;
		die "wrong pattern <$!pattern>" unless so Grammar.parse($!pattern);
	}

	method make-writer(*%defaults --> LogP6::WriterStd:D) {
		LogP6::WriterStd
						.new(self, |%defaults, :$default-handle, :$default-x-pattern);
	}

	method close() {
		with $!handle {
			$!handle.close if $!handle ne $*OUT && $!handle ne $*ERR
		}
	}
}