use LogP6::Level;

role LogP6::Filter {
	method reactive-check($level) { ... }
	method do-before($context) { ... }
	method do-after($context) { ... }
}

role LogP6::FilterConf {
	method clone-with-name($name) { ... }
	method self-check() { ... }
	method make-filter(*%defaults --> LogP6::Filter:D) { ... }
}

class LogP6::FilterConfStd { ... }

class LogP6::FilterStd does LogP6::Filter {
	has LogP6::Level:D $.level is required;
	has List:D $.before-check is required;
	has List:D $.after-check is required;
	has Bool:D $.first-level-check is required;

	only method new(LogP6::FilterConfStd:D $conf, *%defaults) {
		my $first-level-check = $conf.first-level-check // True;
		my $level = $conf.level // %defaults<default-level>;
		my &level-check := chose-level-check($level);
		my $before = ($conf.before-check // ()).Array;
		$before = $first-level-check
				?? $before.append(&level-check)
				!! [&level-check].append($before);
		$before = $before.list;
		self.bless(
			level => $level,
			before-check => $before,
			after-check => $conf.after-check // (),
			:$first-level-check
		);
	}

	method reactive-check($level) {
		!$!first-level-check || $!level <= $level;
	}

	method do-before($context) {
		for @$!before-check -> $check {
			return False unless $check($context);
		}
		True;
	}

	method do-after($context) {
		for @$!before-check -> $check {
			return unless $check($context);
		}
	}

	sub chose-level-check($need-level) {
		given $need-level {
			when trace { return &trace-level-check }
			when debug { return &debug-level-check }
			when info  { return  &info-level-check }
			when warn  { return  &warn-level-check }
			when error { return &error-level-check }
		}
	}

	sub trace-level-check($context) { LogP6::Level::trace <= $context.level }
	sub debug-level-check($context) { LogP6::Level::debug <= $context.level }
	sub  info-level-check($context) { LogP6::Level::info  <= $context.level }
	sub  warn-level-check($context) { LogP6::Level::warn  <= $context.level }
	sub error-level-check($context) { LogP6::Level::error <= $context.level }
}

class LogP6::FilterConfStd does LogP6::FilterConf {
	has Str $.name;
	has LogP6::Level $.level;
	has Bool $.first-level-check;
	has List $.before-check;
	has List $.after-check;

	method clone-with-name($name) {
		self.clone(:$name);
	}

	method self-check() { }

	method make-filter(*%defaults --> LogP6::Filter:D) {
		LogP6::FilterStd.new(self, |%defaults);
	}
}