unit module LogP6;

use UUID;

# filters

class FilterConf {
	has Str $.name;
	has Int $.level;
}

my %fc = %();

proto filter(| --> FilterConf:D) is export { * }

multi sub filter(Str :$name, Int :$level --> FilterConf:D) {
	filter(:$name, :$level, :create);
}

multi sub filter(Str :$name, Int :$level, Bool:D :$create where *.so
		--> FilterConf:D) {
	with $name {
		return %fc{$name} = FilterConf.new: :$name, :$level if $name;
	} else {
		return FilterConf.new: :$level;
	}
}

sub get-filter($name --> FilterConf) is export {
	%fc{$name};
}

# writers

class WriterConf {
	has Str $.name;
	has Str $.pattern is required;
}

my %wc = %();

proto writer(| --> WriterConf:D) is export { * }

multi sub writer(Str :$name, Str:D :$pattern! --> WriterConf:D) {
	writer(:$name, :$pattern, :create);
}

multi sub writer(Str :$name, Str:D :$pattern!, Bool:D :$create where *.so
		--> WriterConf:D) {
	with $name {
		return %wc{$name} = WriterConf.new: :$name, :$pattern if $name;
	} else {
		return WriterConf.new: :$pattern;
	}
}

sub get-writer($name --> WriterConf) is export {
	%wc{$name};
}

# cliches

my @cliches;
my $clishes-names = SetHash.new;

class Cliche {
	has Str:D $.name is required;
	has $.matcher is required;
	has Int:D $.default-level is required;
	has Positional:D $.parts is required;
}

proto cliche(| --> Nil) is export { * }

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ Str:D || $matcher ~~ Regex:D,
	Int:D :$default-level = 3, Positional:D :$parts
) {
	die "cliche with name $name already exists" if $clishes-names{$name};
	die "need more parts" if $parts.elems < 1;
	for |$parts -> $part {
		die "one or more parts are empty" if $part.elems < 1;
		die "one or more parts has more then two elems" if $part.elems > 2;

		if $part ~~ Positional {
			check-cliche-writer($part[0]);
			check-cliche-filter($part[1]);
		} else {
			check-cliche-writer($part);
		}
	}

	my $good-parts = (|$parts).map(-> $part { $part ~~ Positional ??
		(get-cliche-writer-name($part[0]), get-cliche-filter-name($part[1])) !!
		(get-cliche-writer-name($part),    get-cliche-filter-name(Any))
	}).list;

	my $good-matcher;
	if $matcher ~~ Regex {
		$good-matcher = $matcher;
	} elsif $matcher ~~ Str {
		if $matcher.starts-with("/") && $matcher.ends-with("/") {
			my $m = $matcher.substr(1, $matcher.chars - 2);
			$good-matcher = /<$m>/;
		} else {
			$good-matcher = $matcher;
		}
	}


	$clishes-names<$name> = True;
	@cliches.push: Cliche.new(:$name, :$default-level,
		matcher => $good-matcher, parts => $good-parts);
}

sub check-cliche-writer($writer) {
	die "writer of some part is a type object" without $writer;
	if $writer ~~ Str {
		die "writer with name $writer does not exist" without %wc{$writer};
	} elsif $writer ~~ WriterConf {
		with $writer.name -> $wname {
			die "writer with name $wname are not stored" without %wc{$wname};
		}
	} else {
		die "the are not either writer or its name at the first position of some part";
	}
}

sub get-cliche-writer-name($writer) {
	check-cliche-writer($writer);
	return $writer if $writer ~~ Str;
	return $writer.name with $writer.name;
	my $clone = $writer.clone(name => UUID.new.Str);
	%wc{$clone.name} = $clone;
	return $clone.name;
}

sub check-cliche-filter($filter) {
	with $filter {
		if $filter ~~ Str {
			die "filter with name $filter does not exist" without %fc{$filter};
		} elsif $filter ~~ FilterConf {
			with $filter.name -> $fname {
				die "filter with name $fname are not stored" without %fc{$fname};
			}
		}
	}
}

sub get-cliche-filter-name($filter) {
	check-cliche-filter($filter);
	with $filter {
		return $filter if $filter ~~ Str;
		if $filter ~~ FilterConf {
			return $filter.name with $filter.name;
			my $clone = $filter.clone(name => UUID.new.Str);
			%fc{$clone.name} = $clone;
			return $clone.name;
		}
	}
	my $empty = filter(name => UUID.new.Str);
	return $empty.name;
}

# loggers

class Filter {
	has Int:D $.level is required;

	only method new(FilterConf $conf, $default-level) {
		self.bless(
			level => $conf.level // $default-level,
		);
	}

	submethod TWEAK() {

	}
}

class Writer {
	has Str $.pattern;

	only method new(WriterConf:D $conf) {
		self.bless(
			pattern => $conf.pattern,
		);
	}

	submethod TWEAK() {

	}
}

class Logger {
	has Str:D $.trait is required;
	has List:D $.parts is required;
}

my %loggers = %();

sub create-logger($trait, $cliche) {
	my $level = $cliche.default-level;
	my $parts = $cliche.parts
		.map(-> $p { (Writer.new(get-writer($p[0])), Filter.new(get-filter($p[1]), $level)) }).List;
	Logger.new(:$trait, :$parts);
}

sub get-logger(Str:D $trait --> Logger:D) is export {
	return $_ with %loggers{$trait};

	for @cliches.reverse -> $cliche {
		if $trait ~~ $cliche.matcher {
			return %loggers{$trait} = create-logger($trait, $cliche);
		}
	}

	die "create default cliche";
}
