unit module LogP6::WriterConf::Pattern;

use LogP6::Level;

role PatternPart {
	method show($) { ... }
}

class Trait does PatternPart {
	method show($context) { $context.trait }
}

role TraitParam does PatternPart {
	# not need eviction. if we use trait ones then we use it all program lifetime
	has %!cache = %();

	method calculate($trait) { ... }

	method show($context) {
		my $trait = $context.trait;
		%!cache{$trait} //= self.calculate($trait);
	}
}

class TraitShort does TraitParam {
	has $.separator;
	has $.minus;
	has $.length;
	has $.abreviature;

	method calculate($trait) {
		my $parts = $trait.split('::').List;
		my $elems = $parts.elems;
		if $!length >= $elems || $!length == 0 {
			return $parts.join($!separator);
		}
		my $middle = $!minus ?? $!length !! $elems - $!length;
		return $parts.kv.map(-> $i, $p {
			if $i < $middle {
				$!abreviature ?? substr($p, 0, $!abreviature) !! Any;
			} else {
				$p;
			}
		}).grep(*.defined).join($!separator);
	}
}

class TraitSprintf does TraitParam {
	has $.placeholder;

	method calculate($trait) {
		sprintf($!placeholder, $trait);
	}
}

class Tid does PatternPart {
	method show($context) { $context.tid }
}

class Tname does PatternPart {
	method show($context) { $context.tname // '' }
}

class Ndc does PatternPart {
	method show($context) { $context.ndc.join: ' ' }
}

class Msg does PatternPart {
	method show($context) { $context.msg }
}

class Mdc does PatternPart {
	has $.key is required;
	method show($context) { $context.mdc{$!key} // '' }
}

class Glue does PatternPart {
	has $.glue is required;
	method new($str) { self.bless(glue => $str) }
	method show($context) { $.glue }
}

class X does PatternPart {
	has $.pieces;
	method show($context) {
		with $context.x() {
			return ($!pieces>>.show($_)).join;
		}
		return '';
	}
}

class XMsg does PatternPart {
	method show($x) { $x.message }
}

class XName does PatternPart {
	method show($x) { $x.^name }
}

class XTrace does PatternPart {
	method show($x) { $x.backtrace }
}

my $digits = ('00', '01' ... '99').List;
my $months = <0 Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>.List;

class Date does PatternPart {
	has $.pieces;
	method show($context) {
		with $context.date() {
			return ($!pieces>>.show($_)).join;
		}
		return '';
	}
}

class DateYearFour does PatternPart {
	method show($d) { $d.year }
}

class DateYearTwo does PatternPart {
	method show($d) { $digits[$d.year % 100] }
}

class DateMonthWord does PatternPart {
	method show($d) { $months[$d.month] }
}

class DateMonthNum does PatternPart {
	method show($d) { $digits[$d.month] }
}

class DateDay does PatternPart {
	method show($d) { $digits[$d.day] }
}

class DateHour does PatternPart {
	method show($d) { $digits[$d.hour] }
}

class DateMinute does PatternPart {
	method show($d) { $digits[$d.minute] }
}

class DateSecond does PatternPart {
	method show($d) { $digits[$d.whole-second] }
}

class DateMSecond does PatternPart {
	method show($d) { round(($d.second - $d.whole-second) * 1000) }
}

class DateZone does PatternPart {
	method show($d) { $d.timezone }
}

class FrameFile does PatternPart {
	method show($context) { $context.callframe.file }
}

class FrameLine does PatternPart {
	method show($context) { $context.callframe.line }
}

class FrameName does PatternPart {
	method show($context) { $context.callframe.code.name }
}

my $lnames = [];
$lnames[LogP6::Level::trace.Int] = 'TRACE';
$lnames[LogP6::Level::debug.Int] = 'DEBUG';
$lnames[LogP6::Level::info.Int]  = 'INFO';
$lnames[LogP6::Level::warn.Int]  = 'WARN';
$lnames[LogP6::Level::error.Int] = 'ERROR';
$lnames .= List;

my $color = [];
$color[LogP6::Level::trace.Int] = "\e[33m"; # yellow
$color[LogP6::Level::debug.Int] = "\e[32m"; # green;
$color[LogP6::Level::info.Int]  = "\e[34m"; # blue;
$color[LogP6::Level::warn.Int]  = "\e[35m"; # magenta;
$color[LogP6::Level::error.Int] = "\e[31m"; # red;
$color .= List;

class LevelName does PatternPart {
	has $.levels;

	method new($conf) {
		my $levels = $lnames.clone.Array;
		my $length = $conf<length> // 0;
		my $colored = $conf<color> // False;
		for 1..5 -> $i {
			$levels[$i] = $conf{$i.Str} // $levels[$i];
			$levels[$i] = sprintf('%-*.*s', $length, $length, $levels[$i])
					if $length > 0;
			$levels[$i] = $color[$i] ~ $levels[$i] ~ "\e[0m" if $colored;
		}

		self.bless(levels => $levels.List);
	}

	method show($context) {
		$!levels[$context.level];
	}
}

grammar Grammar is export {
	token TOP { <item>* }

	proto token item { * }
	# %trait - logger name (trait)
	token item:sym<trait> { '%trait'<trait-params>? }
	token trait-params { \{ <trait-param> \} }
	proto rule trait-param { * }
	rule trait-param:sym<short>
			{ <ws> 'short' '=' '[' $<word>=<-[\]]>+ ']' <real-num> }
	rule trait-param:sym<printf> { <ws> 'sprintf' '=' <word> }
	# %tid - thread id
	token item:sym<tid> { '%tid' }
	# %tname - thread name
	token item:sym<tname> { '%tname' }
	# %msg - message
	token item:sym<msg> { '%msg' }
	# %ndc - ndc-stack
	token item:sym<ndc> { '%ndc' }
	# %mdc{key} - mdc-value
	token item:sym<mdc> { '%mdc'<mdc-param> }
	token mdc-param { \{ <word> \} }
	# glue between items
	token item:sym<glue> { $<text>=<-[%]>+ }
	# %x{$msg $name $trace} - exception {message class-name backtrace}
	token item:sym<x> { '%x'<x-params>? }
	token x-params { \{ <x-param>+ \} }
	proto token x-param { * }
	token x-param:sym<msg> { '$msg' }
	token x-param:sym<name> { '$name' }
	token x-param:sym<trace> { '$trace' }
	token x-param:sym<glue> { $<text>=<-[$}]>+ }
	# %date{$yyyy-$yy-$MM-$MMM-$dd $hh:$mm:$ss:$mss $z} - date and time
	token item:sym<date> { '%date'<date-params>? }
	token date-params { \{ <date-param>+ \} }
	proto token date-param { * }
	token date-param:sym<year> { '$' $<l>='yy' ** 1..2 }
	token date-param:sym<month> { '$' $<l>=M ** 2..3 }
	token date-param:sym<day> { '$dd' }
	token date-param:sym<hour> { '$hh' }
	token date-param:sym<minute> { '$mm' }
	token date-param:sym<second> { '$ss' }
	token date-param:sym<msecond> { '$mss' }
	token date-param:sym<zone> { '$z' }
	token date-param:sym<glue> { $<text>=<-[$}]>+ }
	# %level{WARN=W DEBUG=D ERROR=E TRACE=T INFO=I length=2}
	token item:sym<level> { '%level'<level-params>? }
	token level-params { \{ <level-param>+ \} }
	proto rule level-param { * }
	rule level-param:sym<trace> { 'TRACE' '=' <word> }
	rule level-param:sym<debug> { 'DEBUG' '=' <word> }
	rule level-param:sym<info> { 'INFO' '=' <word> }
	rule level-param:sym<warn> { 'WARN' '=' <word> }
	rule level-param:sym<error> { 'ERROR' '=' <word> }
	rule level-param:sym<length> { 'length' '=' <num> }
	rule level-param:sym<color> { 'color' }
	# %framefile - frame file path
	token item:sym<framefile> { '%framefile' }
	# %frameline - frame file line
	token item:sym<frameline> { '%frameline' }
	# %framename - frame code name
	token item:sym<framename> { '%framename' }

	token word { $<text>=<-[\s}]>+ }
	token minus { '-' }
	token num { $<text>=\d+ }
	token fract { '.'<num> }
	token real-num { <minus>?<num><fract>?}
}

class Actions is export {
	method TOP($/) { make $<item>>>.made.List }
	method item:sym<trait>($/) {
		with $<trait-params> {
			make $<trait-params>.made
		} else {
			make Trait
		}
	}
	method trait-params($/) { make $<trait-param>.made }
	method trait-param:sym<short>($/) {
		make TraitShort.new(:separator($<word>.Str), |$<real-num>.made);
	}
	method trait-param:sym<printf>($/) {
		make TraitSprintf.new(:placeholder($<word>.Str))
	}
	method item:sym<tid>($/) { make Tid }
	method item:sym<tname>($/) { make Tname }
	method item:sym<msg>($/) { make Msg }
	method item:sym<ndc>($/) { make Ndc }
	method item:sym<mdc>($/) { make Mdc.new(key => $<mdc-param>.made) }
	method mdc-param($/) { make $<word>.made }
	method item:sym<glue>($/) { make Glue.new($<text>.Str) }
	method word($/) { make $<text>.Str }
	method item:sym<x>($/) {
		with $<x-params> {
			make X.new(pieces => $<x-params>.made);
		} else {
			make X.new(pieces => (Glue.new("Exception "), XName, Glue.new(': '), XMsg,
					Glue.new("\n"), XTrace));
		}
	}
	method x-params($/) { make $<x-param>>>.made.List }
	method x-param:sym<msg>($/) { make XMsg }
	method x-param:sym<name>($/) { make XName }
	method x-param:sym<trace>($/) { make XTrace.new }
	method x-param:sym<glue>($/) { make Glue.new($<text>.Str) }
	method item:sym<date>($/) {
		with $<date-params> {
			make Date.new(pieces => $<date-params>.made);
		} else {
			make Date.new(pieces => (DateHour, Glue.new(':'), DateMinute,
					Glue.new(':'), DateSecond, Glue.new(':'), DateMSecond));
		}
	}
	method date-params($/) { make $<date-param>>>.made.List }
	method date-param:sym<year>($/) {
		make $<l>.chars == 4 ?? DateYearFour !! DateYearTwo;
	}
	method date-param:sym<month>($/) {
		make $<l>.chars == 2 ?? DateMonthNum !! DateMonthWord;
	}
	method date-param:sym<day>($/) { make DateDay }
	method date-param:sym<hour>($/) { make DateHour }
	method date-param:sym<minute>($/) { make DateMinute }
	method date-param:sym<second>($/) { make DateSecond }
	method date-param:sym<msecond>($/) { make DateMSecond }
	method date-param:sym<zone>($/) { make DateZone }
	method date-param:sym<glue>($/) { make Glue.new($<text>.Str) }
	method item:sym<level>($/) {
		with $<level-params> {
			make LevelName.new($<level-params>.made);
		} else {
			make LevelName.new(%());
		}
	}
	method level-params($/) { make $<level-param>>>.made.hash }
	method level-param:sym<trace>($/) { make Level::trace.Int.Str => $<word>.Str }
	method level-param:sym<debug>($/) { make Level::debug.Int.Str => $<word>.Str }
	method level-param:sym<info>($/) { make Level::info.Int.Str => $<word>.Str }
	method level-param:sym<warn>($/) { make Level::warn.Int.Str => $<word>.Str }
	method level-param:sym<error>($/) { make Level::error.Int.Str => $<word>.Str }
	method level-param:sym<length>($/) { make 'length' => $<num>.made.Str }
	method level-param:sym<color>($/) { make 'color' => True }
	method item:sym<framefile>($/) { make FrameFile }
	method item:sym<frameline>($/) { make FrameLine }
	method item:sym<framename>($/) { make FrameName }
	method minus($/) { make True }
	method num($/) { make $<text>.Int }
	method fract($/) { make $<num>.made }
	method real-num($/) {
		make %(
			:length($<num>.made),
			:abreviature($<fract>.made // 0),
			:minus($<minus>.made // False)
		);
	}
}