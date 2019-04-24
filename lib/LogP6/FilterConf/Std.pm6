use LogP6::FilterConf;
use LogP6::Filter::Std;

class LogP6::FilterConf::Std does LogP6::FilterConf {
	has Str $.name;
	has LogP6::Level $.level;
	has Bool $.first-level-check;
	has List $.before-check;
	has List $.after-check;

	method name(--> Str) {
		$!name;
	}

	method clone-with-name($name --> LogP6::FilterConf:D) {
		self.clone(:$name);
	}

	method make-filter(*%defaults --> LogP6::Filter:D) {
		my $first-level-check = $!first-level-check //
				%defaults<default-first-level-check>;
		my $level = $!level // %defaults<default-level>;
		my $reactive-level = $first-level-check ?? $level !! LogP6::Level::trace;
		my &level-check := chose-level-check($level);
		my $before = ($!before-check // ()).Array;
		$before = $first-level-check
				?? [&level-check].push(|$before)
				!! $before.push(&level-check);
		$before = $before.List;

		LogP6::Filter::Std.new(
			:$reactive-level,
			before-check => $before,
			after-check => $!after-check // (),
		);
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
