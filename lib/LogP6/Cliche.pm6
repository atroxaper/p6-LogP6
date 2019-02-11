use LogP6::Level;
use LogP6::Wrapper;

class LogP6::Cliche {
	has Str:D $.name is required;
	has $.matcher is required;

	has Str $.default-pattern;
	has Bool $.default-auto-exceptions;
	has IO::Handle $.default-handle;
	has Str $.default-x-pattern;

	has LogP6::Level $.default-level;
	has Bool $.default-first-level-check;

	has Positional $.writers;
	has Positional $.filters;
	has Positional $.grooves;
	has LogP6::Wrapper $.wrapper;

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
