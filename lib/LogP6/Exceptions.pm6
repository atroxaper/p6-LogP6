class X::LogP6::PatternIsNotValid is Exception {
	has $.pattern;
	method message() {
		"Wrong writer pattern format: <$!pattern>";
	}
}

multi sub logp6-error(Exception:D $x) is export {
	$*ERR.print('LogP6 error: ', $x.^name, ': ', $x.message, "\n", $x.backtrace);
}

multi sub logp6-error(Str:D $x) is export {
	$*ERR.say('LogP6 error: ', $x);
}