use LogP6::Filter;
use LogP6::FilterConf;
use LogP6::Level;

class LogP6::Filter::Std does LogP6::Filter {
	has LogP6::Level:D $.reactive-level is required;
	has List:D $.before-check is required;
	has List:D $.after-check is required;

	method reactive-level() {
		$!reactive-level;
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
}
