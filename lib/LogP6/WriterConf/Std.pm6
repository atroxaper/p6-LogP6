use LogP6::WriterConf;
use LogP6::WriterConf::Pattern;
use LogP6::Writer::Std;
use LogP6::Exceptions;

class LogP6::WriterConf::Std does LogP6::WriterConf {
	has Str $.name;
	has Str $.pattern;
	has IO::Handle $.handle;
	has Bool $.auto-exceptions;

	method name(--> Str) {
		$!name;
	}

	method clone-with-name($name --> LogP6::WriterConf:D) {
		self.clone(:$name);
	}

	method self-check(--> Nil) {
		return without $!pattern;
		X::LogP6::PatternIsNotValid.new(:$!pattern).throw
				unless so Grammar.parse($!pattern);
	}

	method make-writer(*%defaults --> LogP6::Writer:D) {
		LogP6::Writer::Std.new(self, |%defaults);
	}

	method close(--> Nil) {
		with $!handle {
			$!handle.close unless $!handle eqv $*OUT || $!handle eqv $*ERR
		}
	}
}
