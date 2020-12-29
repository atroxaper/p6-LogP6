use LogP6::Writer;
use LogP6::WriterConf;
use LogP6::WriterConf::Pattern;

class LogP6::Writer::Std does LogP6::Writer {
	has Str:D $.pattern is required;
	has IO::Handle:D $.handle is required;

	has @!pieces;

	submethod TWEAK() {
		@!pieces := Grammar.parse($!pattern, actions => Actions).made;
	}

	method write($context) {
		$!handle.say(|@!pieces>>.show($context));
	}
}