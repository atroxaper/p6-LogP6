use Log::Fast::Context 'Context';

class Log::Fast::Decider {
	has Str $.name is required;
	has Int $.level is required;
	has Positional $.first-filters;
	has Positional $.second-filters;
	has Bool $.check-level-first = True;

	method pass-level(Log::Fast::Decider:D: Int $level-want --> Bool:D) {
		!$!check-level-first || $!level <= $level-want;
	}

	method pass-first-filters(Log::Fast::Decider:D: Context:D $context --> Bool:D) {
		for $!first-filters -> $filter {
			return False unless $filter($context);
		}
		return $!level <= $context.level-want;
	}

	method pass-second-filter(Log::Fast::Decider:D: Context:D $context --> Bool:D) {
		for $!second-filters -> $filter {
			return False unless $filter($context);
		}
		return True;
	}
}

sub EXPORT($short-name?) {
	%(do $short-name => Log::Fast::Decider if $short-name)
}
