use LogP6::FilterConf;
use LogP6::Filter::Std;

class LogP6::FilterConf::Std does LogP6::FilterConf {
	has Str $.name;
	has LogP6::Level $.level;
	has Bool $.first-level-check;
	has List $.before-check;
	has List $.after-check;

	method name() {
		$!name;
	}

	method clone-with-name($name) {
		self.clone(:$name);
	}

	method self-check() { }

	method make-filter(*%defaults --> LogP6::Filter:D) {
		LogP6::Filter::Std.new(self, |%defaults);
	}
}
