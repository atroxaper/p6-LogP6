class Log::Fast::Context {
	has Str $.mark;
	has Int $.level-want is rw;
	has Int $.level-agreed is rw;
	has IO::Handle $.io is rw;
	has DateTime $.date-time is rw;
	has Int $.pid is rw;
	has Str $.logger-regex is rw;
	has Str $.msg is rw;
	has Str $.to-io is rw;
	has Hash $.context-map is rw;
	has Positional $.context-stack;
}

sub EXPORT($short-name?) {
	%(do $short-name => Log::Fast::Context if $short-name)
}