unit module LogP6;


# TODO
# 1. add support of "" (default) writers and filters (create them at start)
# 2. add START support (create default)
# 3. add STOP support (close all writers)

use UUID;

my @cliches = [];
my $clishes-names = SetHash.new;
my %loggers = %();
my %clishes-to-loggers = %();
my Lock \lock .= new;

my \default-pattern = "default %s";
my \default-level = 2;

enum Level is export (trace => 1, debug => 2, info => 3, warn => 4, error => 5);

class FilterConf {
	has Str $.name;
	has Level $.level;
}

class WriterConf {
	has Str $.name;
	has Str $.pattern is required;
}

my role GroovesPartsManager[$lock, $part-type, $part-name, ::Type] {
	my %parts = %();

	method create(Str :$name, *%fields) {
		with $name {
			return $lock.protect({
				die "$part-name with name $name already exists" with %parts{$name};
				%parts{$name} = Type.new: :$name, |%fields;
			});
		} else {
			return Type.new: |%fields;
		}
	}

	method update(Str:D :$name!, *%fields) {
		$lock.protect({
			die "there is no $part-name with name $name" without %parts{$name};
			my $old = %parts{$name}:delete;
			my %new-fields = %();
			for %fields.kv -> $f-name, $f-value {
				%new-fields{$f-name} = $old."$f-name"() // $f-value;
			}
			my $new = self.create(:$name, |%new-fields);
			update-loggers(find-cliche-with($name, $part-type));
			return $old;
		});
	}

	method replace(Str:D :$name!, *%fields) {
		$lock.protect({
			my $old = %parts{$name}:delete;
			my $new = self.create(:$name, |%fields);
			update-loggers(find-cliche-with($name, $part-type));
			return $old // Type;
		});
	}

	method remove(Str:D :$name!) {
		$lock.protect({
			my $old = %parts{$name}:delete;
			with $old {
				my $new-name = self.create(name => UUID.new.Str).name;
				my @found := find-cliche-with($old.name, $part-type);
				for @found -> $old-cliche {
					my $new-cliche = $old-cliche
							.copy-with-new($old.name, $new-name, $part-type);
					change-cliche($old-cliche, $new-cliche);
				}
				update-loggers(@found);
			}
			return $old // Type;
		});
	}

	method get(Str:D $name) {
		$lock.protect({ %parts{$name} // Type });
	}

	method put(Type:D $part) {
		$lock.protect({ %parts{$part.name} = $part });
	}
}

my $filter-manager =
		GroovesPartsManager[lock, (filter => True), 'filter', FilterConf].new;
my $writer-manager =
		GroovesPartsManager[lock, (writer => True), 'writer', WriterConf].new;

sub get-filter(Str:D $name! --> FilterConf) is export {
	$filter-manager.get($name);
}

sub level(Level:D $level --> FilterConf:D) is export {
	$filter-manager.create(:$level);
}

proto filter(| --> FilterConf) is export { * }

multi sub filter(Str :$name, Level :$level --> FilterConf:D) {
	$filter-manager.create(:$name, :$level);
}

multi sub filter(Str :$name, Level :$level, Bool:D :$create! where *.so
		--> FilterConf:D
) {
	$filter-manager.create(:$name, :$level);
}

multi sub filter(Str:D :$name!, Level :$level, Bool:D :$update! where *.so
		--> FilterConf:D
) {
	$filter-manager.update(:$name, :$level);
}

multi sub filter(Str:D :$name!, Level :$level, Bool:D :$replace! where *.so
		--> FilterConf
) {
	$filter-manager.replace(:$name, :$level);
}

multi sub filter(Str:D :$name!, Bool:D :$remove! where *.so --> FilterConf) {
	$filter-manager.remove(:$name);
}

sub get-writer(Str:D $name! --> WriterConf) is export {
	$writer-manager.get($name);
}

proto writer(| --> WriterConf) is export { * }

multi sub writer(Str :$name, Str :$pattern --> WriterConf:D) {
	$writer-manager.create(:$name, :$pattern);
}

multi sub writer(Str :$name, Str :$pattern, Bool:D :$create where *.so
		--> WriterConf:D
) {
	$writer-manager.create(:$name, :$pattern);
}

multi sub writer(Str:D :$name!, Str :$pattern, Bool:D :$update! where *.so
		--> WriterConf:D
) {
	$writer-manager.update(:$name, :$pattern);
}

multi sub writer(Str:D :$name!, Str :$pattern, Bool:D :$replace! where *.so
		--> WriterConf
) {
	$writer-manager.replace(:$name, :$pattern);
}

multi sub writer(Str:D :$name!, Bool:D :$remove! where *.so --> WriterConf) {
	$writer-manager.remove(:$name);
}

# -------------------

sub find-cliche-with(Str:D $name, Bool :$writer, Bool :$filter --> List:D) {
	my @result;
	@result.push(@cliches.grep(*.has($name, :writer)).list) if $writer;
	@result.push(@cliches.grep(*.has($name, :filter)).list) if $filter;
	@result>>.List.flat.unique.list;
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

class Cliche {
	has Str:D $.name is required;
	has $.matcher is required;
	has Int $.default-level;
	has Str $.default-pattern;
	has Positional $.writers;
	has Positional $.filters;

	method has(Cliche:D: $name, Bool :$writer, Bool :$filter --> Bool:D) {
		my $iter = $writer ?? $!writers !! $filter ?? $!filters !! ();
		so $iter.grep(* eq $name);
	}

	method copy-with-new($old-name, $new-name, Bool :$writer, Bool :$filter) {
		my $new-writers = $!writers;
		my $new-filters = $!filters;
		$new-writers = $new-writers
				.map(-> $w { $w eq $old-name ?? $new-name !! $w }).list if $writer;
		$new-filters = $new-filters
				.map(-> $f { $f eq $old-name ?? $new-name !! $f }).list if $filter;

		self.clone(writers => $new-writers, filters => $new-filters);
	}
}

proto cliche(| --> Nil) is export { * }

multi sub cliche(
	Str:D :$name!, :$matcher! where $matcher ~~ any(Str:D, Regex:D),
	Level :$default-level, Str :$default-pattern, Positional :$grooves
) {
	die "cliche with name $name already exists" if $clishes-names{$name};
	my $all-grooves = ($grooves // (),)>>.List.flat;
	die "grooves must have even amount of elements" unless $all-grooves %% 2;

	check-cliche-writer($_) for $all-grooves[0,2 ...^ *];
	check-cliche-filter($_) for $all-grooves[1,3 ...^ *];

	my $writers-names = $all-grooves[0,2 ...^ *]>>.&get-cliche-writer-name.List;
	my $filters-names = $all-grooves[1,3 ...^ *]>>.&get-cliche-filter-name.List;

	$clishes-names<$name> = True;
	@cliches.push: Cliche.new(:$name, :$default-level, :$default-pattern,
			:$matcher, writers => $writers-names, filters => $filters-names);
}

sub check-cliche-writer($writer) {
	die "writer of some part is a type object" without $writer;
	if $writer ~~ Str {
		die "writer with name $writer does not exist"
				without $writer-manager.get($writer);
	} elsif $writer ~~ WriterConf {
		with $writer.name -> $wname {
			die "writer with name $wname are not stored"
					without $writer-manager.get($wname);
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
	$writer-manager.put($clone);
	return $clone.name;
}

sub check-cliche-filter($filter) {
	with $filter {
		if $filter ~~ Str {
			die "filter with name $filter does not exist"
					without $filter-manager.get($filter);
		} elsif $filter ~~ FilterConf {
			with $filter.name -> $fname {
				die "filter with name $fname are not stored"
						without $filter-manager.get($fname);
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
			$filter-manager.put($clone);
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
	has List:D $.grooves is required;
}

sub create-logger($trait, $cliche) {
	my $level = $cliche.default-level // default-level;
	my $pattern = $cliche.default-pattern // default-pattern;
 	my $grooves = (0...^$cliche.writers.elems).list.map(-> $i { (
			Writer.new(get-writer($cliche.writers[$i]), $pattern),
			Filter.new(get-filter($cliche.filters[$i]), $level)
	) }).list;
	Logger.new(:$trait, :$grooves);
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