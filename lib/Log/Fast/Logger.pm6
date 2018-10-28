class Log::Fast::Logger {
	has Str:D $.regex is required;
	has Str $.name;
	has Positional $.entry;

	method debug(Log::Fast::Logger:D: Str:D $msg, Str:D :$mark) {

	}


}

sub EXPORT($short-name?) {
	%(do $short-name => Log::Fast::Logger if $short-name)
}