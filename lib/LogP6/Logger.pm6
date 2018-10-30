class LogP6::Cliche {
	has Str:D $.name is required;
	has $.matcher is required;
	has Int $.default-level;
	has Str $.default-pattern;
	has Positional $.writers;
	has Positional $.filters;

	method has(LogP6::Cliche:D: $name, Str:D $type where * ~~ any('writer', 'filter')
			--> Bool:D
	) {
		my $iter = $type eq 'writer' ?? $!writers !! $!filters;
		so $iter.grep(* eq $name);
	}

	method copy-with-new(LogP6::Cliche:D: $old, $new,
			Str:D $type where * ~~ any('writer', 'filter')
	) {
		my $new-writers = $!writers;
		my $new-filters = $!filters;
		$new-writers = $new-writers.map(-> $w { $w eq $old ?? $new !! $w }).list
				if $type eq 'writer';
		$new-filters = $new-filters.map(-> $f { $f eq $old ?? $new !! $f }).list
				if $type eq 'filter';
		self.clone(writers => $new-writers, filters => $new-filters);
	}
}

class LogP6::Logger does LogP6::LoggerRole {
	has Str:D $.trait is required;
	has List:D $.grooves is required;

	method info(Str:D $msg) {

	}

}

role LogP6::LoggerRole {

	method info(Str:D $msg) { ... }
	method debug(Str:D $msg) { ... }
}