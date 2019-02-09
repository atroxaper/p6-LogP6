use LogP6::Filter;
use LogP6::FilterConf;
use LogP6::Level;

class LogP6::Filter::Std does LogP6::Filter {
	has LogP6::Level:D $.level is required;
	has List:D $.before-check is required;
	has List:D $.after-check is required;
	has Bool:D $.first-level-check is required;

	only method new(LogP6::FilterConf:D $conf, *%defaults) {
		my $first-level-check = $conf.first-level-check // True;
		my $level = $conf.level // %defaults<default-level>;
		my &level-check := chose-level-check($level);
		my $before = ($conf.before-check // ()).Array;
		$before = $first-level-check
				?? [&level-check].push(|$before)
				!! $before.push(&level-check);
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
		for @$!after-check -> $check {
			return unless $check($context);
		}
	}

	sub chose-level-check($need-level) {
		given $need-level {
			when LogP6::Level::trace { return &trace-level-check }
			when LogP6::Level::debug { return &debug-level-check }
			when LogP6::Level::info  { return  &info-level-check }
			when LogP6::Level::warn  { return  &warn-level-check }
			when LogP6::Level::error { return &error-level-check }
		}
	}

	sub trace-level-check($context) { LogP6::Level::trace <= $context.level }
	sub debug-level-check($context) { LogP6::Level::debug <= $context.level }
	sub  info-level-check($context) { LogP6::Level::info  <= $context.level }
	sub  warn-level-check($context) { LogP6::Level::warn  <= $context.level }
	sub error-level-check($context) { LogP6::Level::error <= $context.level }
}
