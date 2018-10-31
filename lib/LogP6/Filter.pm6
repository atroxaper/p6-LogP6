use LogP6::Level;

class LogP6::FilterConf {
	has Str $.name;
	has LogP6::Level $.level;
	has Bool $.first-level-check;
	has List $.before-check;
	has List $.after-check;
}

class LogP6::Filter {
	has LogP6::Level:D $.level is required;
	has List:D $.before-check is required;
	has List:D $.after-check is required;

	only method new(LogP6::FilterConf:D $conf, LogP6::Level:D $default-level) {
		my $first-level-check = $conf.first-level-check // True;
		my $level = $conf.level // $default-level;
		# todo. make five static sub
		my &level-check := make-level-check($level);
		my $before = ($conf.before-check // ()).Array;
		$before = $first-level-check
				?? $before.append(&level-check)
				!! [&level-check].append($before);
		$before = $before.list;
		self.bless(
			level => $level,
			before-check => $before,
			after-check => $conf.after-check // ()
		);
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

	sub make-level-check($need-level) {
		-> $c { $need-level <= $c.level() };
	}
}