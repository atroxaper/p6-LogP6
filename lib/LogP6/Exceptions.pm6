class X::LogP6::PatternIsNotValid is Exception {
	has $.pattern;
	method message() {
		"Wrong writer pattern format: <$!pattern>";
	}
}
