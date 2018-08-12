use Log::Fast::Context 'Context';

class Log::Fast::Layout {
	has Str $.str is required;

	method compile(Log::Fast::Layout:D: Context:D :$context --> Nil) {
		$context.to-io = $context.msg ~ $!str;
	}
}

sub EXPORT($short-name?) {
	%(do $short-name => Log::Fast::Layout if $short-name)
}