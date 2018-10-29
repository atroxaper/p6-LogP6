unit module LogP6;

use UUID;

# filters

my %fc = %();
my %wc = %();
my @cliches = [];
my $clishes-names = SetHash.new;
my %loggers = %();
my %clishes-to-loggers = %();
my Lock \lock .= new;

my \default-pattern = "default %s";
my \default-level = 2;

enum Level (trace => 1, debug => 2, info => 3, warn => 4, error => 5);

class FilterConf {
	has Str $.name;
	has Level $.level;
}

class WriterConf {
	has Str $.name;
	has Str $.pattern is required;
}

proto filter(| --> FilterConf:D) is export { * }

sub level(Level:D $level --> FilterConf:D) is export {
	filter(:$level, :create);
}

multi sub filter(Str :$name, Level :$level --> FilterConf:D) {
	lock.protect({ filter(:$name, :$level, :create) });
}

multi sub filter(Str :$name, Level :$level, Bool:D :$create! where *.so
		--> FilterConf:D) {
		with $name {
			return lock.protect({
				die "filter with name $name already exists" with %fc{$name};
				%fc{$name} = FilterConf.new: :$name, :$level;
			});
		} else {
			return FilterConf.new: :$level;
		}

}

multi sub filter(Str:D :$name!, Level :$level, Bool:D :$update! where *.so
		--> FilterConf:D) {
	lock.protect({
		die "there is no filter with name $name" without %fc{$name};
		my $old = %fc{$name}:delete;
		my $new = filter(:$name, level => $level // $old.level, :create);
		update-loggers(find-cliche-with($name, :filter));
		return $old;
	});
}

multi sub filter(Str:D :$name!, Level :$level, Bool:D :$replace! where *.so
		--> FilterConf) {
	lock.protect({
		my $old = %fc{$name}:delete;
		my $new = filter(:$name, level => $level, :create);
		update-loggers(find-cliche-with($name, :filter));
		return $old;
	});
}

multi sub filter(Str:D :$name!, Bool:D :$delete! where *.so --> FilterConf) {
	lock.protect({
		my $old = %fc{$name}:delete;
		with $old {
			my $new-name = filter(name => UUID.new.Str, :create).name;
			my @found := find-cliche-with($old.name, :filter);
			for @found -> $old-cliche {
				my $new-cliche = $old-cliche
						.copy-with-new($old.name, $new-name, :filter);
				change-cliche($old-cliche, $new-cliche);
			}
			update-loggers(@found);
		}
		return $old;
	});
}

sub get-filter($name --> FilterConf) is export {
	lock.protect({ %fc{$name} // FilterConf });
}

sub find-cliche-with(Str:D $name, Bool :$writer, Bool :$filter --> List:D) {
	my @result;
	if $writer {
		@result.push: @cliches.grep(-> $c { $c.has-writer($name) }).list;
	}
	if $filter {
		@result.push: @cliches.grep(-> $c { $c.has-filter($name) }).list;
	}
	@result.unique.list;
}

sub update-loggers(Positional:D $cliches) {
	for |$cliches -> $cliche {
		for %clishes-to-loggers{$cliche.name} -> $trait {
			%loggers{$trait} = create-logger($trait, $cliche);
		}
	}
}

sub change-cliche($old-cliche, $new-cliche) {
	for @cliches.kv -> $i, $cliche {
		if $cliche.name eq $old-cliche.name {
			@cliches[$i] = $new-cliche;
			return;
		}
	}
	die "can not chnage cliche with name $($old-cliche.name)";
}

proto writer(| --> WriterConf:D) is export { * }

multi sub writer(Str :$name, Str :$pattern --> WriterConf:D) {
	lock.protect({ writer(:$name, :$pattern, :create) });
}

multi sub writer(Str :$name, Str :$pattern, Bool:D :$create where *.so
		--> WriterConf:D) {
	with $name {
		return lock.protect({
			die "writer with name $name already exists" with %wc{$name};
			return %wc{$name} = WriterConf.new: :$name, :$pattern;
		});
	} else {
		return WriterConf.new: :$pattern;
	}
}

multi sub writer(Str:D :$name!, Str :$pattern, Bool:D :$update! where *.so
		--> WriterConf:D) {
	lock.protect({
		die "there is no writer with name $name" without %wc{$name};
		my $old = %wc{$name}:delete;
		my $new = writer(:$name, pattern => $pattern // $old.pattern, :create);
		update-loggers(find-cliche-with($name, :writer));
		return $old;
	});
}

multi sub writer(Str:D :$name!, Str :$pattern, Bool:D :$replace! where *.so
		--> WriterConf) {
	lock.protect({
		my $old = %wc{$name}:delete;
		my $new = writer(:$name, pattern => $pattern, :create);
		update-loggers(find-cliche-with($name, :writer));
		return $old;
	});
}

multi sub writer(Str:D :$name!, Bool:D :$delete! where *.so --> WriterConf) {
	lock.protect({
		my $old = %wc{$name}:delete;
		with $old {
			my $new-name = writer(name => UUID.new.Str, :create).name;
			my @found := find-cliche-with($old.name, :writer);
			for @found -> $old-cliche {
				my $new-cliche = $old-cliche
						.copy-with-new($old.name, $new-name, :writer);
				change-cliche($old-cliche, $new-cliche);
			}
			update-loggers(@found);
		}
		return $old;
	});
}

sub get-writer($name --> WriterConf) is export {
	lock.protect({ %wc{$name} });
}

# cliches

class Cliche {
	has Str:D $.name is required;
	has $.matcher is required;
	has Int $.default-level;
	has Str $.default-pattern;
	has Positional $.parts;

	method has-writer(Cliche:D: $name --> Bool:D) {
		self!has-part($name, 0);
	}

	method has-filter(Cliche:D: $name --> Bool:D) {
		self!has-part($name, 1);
	}

	method !has-part(Cliche:D: $name, $index where $index == any(0, 1)
	) {
		for $!parts -> $p {
				return True if $[$index].name eq $name;
		}
		return False;
	}

	method copy-with-new($old-name, $new-name, Bool :$writer, Bool :$filter) {
		my &change = -> $part {
			my ($w, $f) = |$part;
			my $ww = $writer && $w eq $old-name ?? $new-name !! $w;
			my $ff = $filter && $f eq $old-name ?? $new-name !! $f;
			($ww, $ff);
		}
		my $good-parts = $!parts.map(-> $p { change($p) }).list;
		Cliche.new(name => $!name, default-level => $!default-level,
				default-pattern => $!default-pattern, matcher => $!matcher,
				parts => $good-parts);
	}
}

proto cliche(| --> Nil) is export { * }

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ Str:D || $matcher ~~ Regex:D,
	Level :$default-level, Str :$default-pattern, Positional :$parts
) {
	die "cliche with name $name already exists" if $clishes-names{$name};
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
	@cliches.push: Cliche.new(:$name, :$default-level, :$default-pattern,
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
	has Level:D $.level is required;

	only method new(FilterConf:D $conf, Level:D $default-level) {
		self.bless(
			level => $conf.level // $default-level,
		);
	}

	submethod TWEAK() {

	}
}

class Writer {
	has Str:D $.pattern is required;

	only method new(WriterConf:D $conf, Str:D $default-pattern) {
		self.bless(
			pattern => $conf.pattern // $default-pattern,
		);
	}

	submethod TWEAK() {

	}
}

class Logger {
	has Str:D $.trait is required;
	has List:D $.parts is required;
}



sub create-logger($trait, $cliche) {
	my $level = $cliche.default-level // default-level;
	my $pattern = $cliche.default-pattern // default-pattern;
	my $parts = $cliche.parts
			.map(-> $p { (
					Writer.new(get-writer($p[0]), $pattern),
					Filter.new(get-filter($p[1]), $level)
			) }).List;
	Logger.new(:$trait, :$parts);
}

sub find-cliche-for-trait($trait) {
	for @cliches.reverse -> $cliche {
		return $cliche if $trait ~~ $cliche.matcher;
	}

	die "create default cliche";
}

sub get-logger(Str:D $trait --> Logger:D) is export {
	return $_ with %loggers{$trait};

	my $cliche = find-cliche-for-trait($trait);
	my $logger = create-logger($trait, $cliche);

	%loggers{$trait} = $logger;
	(%clishes-to-loggers{$trait} //= []).push: $trait;

	return $logger;
}
