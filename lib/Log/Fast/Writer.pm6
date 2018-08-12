use Log::Fast::Layout 'Layout';
use Log::Fast::Context 'Context';

class Log::Fast::Writer {
	has Str:D $.name is required;
	has IO::Handle:D $.io is required;
	has Layout:D $.layout is required;

	method write(Log::Fast::Writer:D: Context:D $context --> Nil) {
		$.io.say($context.to-io);
	}

	method prepare(Log::Fast::Writer:D: Context:D $context --> Nil) {
		$!layout.compile($context);
	}
}

sub EXPORT($short-name?) {
	%(do $short-name => Log::Fast::Writer if $short-name)
}
