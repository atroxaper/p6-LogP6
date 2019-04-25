unit module LogP6::ConfigFile;

use JSON::Fast;

use LogP6::WriterConf::Std;
use LogP6::FilterConf::Std;
use LogP6::Level;
use LogP6::Cliche;
use LogP6::Wrapper::Transparent;

class LogP6::Config {
	has $.writers = ();
	has $.filters = ();
	has $.cliches = ();
	has $.default-pattern;
	has $.default-auto-exceptions;
	has $.default-handle;
	has $.default-x-pattern;
	has $.default-level;
	has $.default-first-level-check;
	has $.default-wrapper;
}

sub default-config-path() is export {
	my $env = %*ENV<LOG_P6_JSON>;
	if $env.defined && $env.trim.Bool {
		return $env.trim;
	} elsif './log-p6.json'.IO.e {
		return './log-p6.json';
	} else {
		Nil;
	}
}

class LogP6::ConfigFile {
	has %!current-cache = %();
	has %!previous-cache = %();

	method parse-config(LogP6::ConfigFile:D: IO() $file-path) is export {
		CATCH {
			default {
				die "Cannot read and create config from file $file-path. Cause "
								~ $_.^name ~ ': ' ~ $_.gist, "\n";
			}
		}
		return LogP6::Config.new unless $file-path.e;
		my $file-content = slurp($file-path).trim;
		die "config file $file-path is empty" if $file-content.chars == 0;
		my \conf = from-json($file-content);

		my $config = LogP6::Config.new(
			writers => self!list(conf<writers>, 'writer'),
			filters => self!list(conf<filters>, 'filter'),
			cliches => self!list(conf<cliches>, 'cliche'),
			default-pattern => self!string-e(conf<default-pattern>),
			default-auto-exceptions => self!bool(conf<default-auto-exceptions>),
			default-handle => self!handle(conf<default-handle>),
			default-x-pattern => self!string-e(conf<default-x-pattern>),
			default-level => self!level(conf<default-level>),
			default-first-level-check => self!bool(conf<default-first-level-check>),
			default-wrapper => self!wrapper(conf<default-wrapper>)
		);

		%!previous-cache = %!current-cache;
		%!current-cache = %();

		return $config;
	}

	method !list(\json, $each) {
		return () without json;
		return json.map({self!"$each"($_)}).eager.List;
	}

	method !writer(\json) {
		given json<type> {
			when 'std' {
				return LogP6::WriterConf::Std.new(
					name => json<name> // Str,
					pattern => self!string-e(json<pattern>),
					handle => self!handle(json<handle>),
					auto-exceptions => self!bool(json<auto-exceptions>)
				);
			}
			when 'custom' {
				return self!custom(json);
			}
			default {
				die "Wrong writer type $_";
			}
		}
	}

	method !filter(\json) {
		given json<type> {
			when 'std' {
				return LogP6::FilterConf::Std.new(
					name => json<name> // Str,
					level => self!level(json<level>),
					first-level-check => json<first-level-check> // Bool,
					before-check => self!list(json<before-check>, 'custom'),
					after-check => self!list(json<after-check>, 'custom')
				);
			}
			when 'custom' {
				return self!custom(json);
			}
			default {
				die "Wrong filter type $_";
			}
		}
	}

	method !bool(\json) {
		return Bool without json;
		return json if json ~~ Bool;
		return json eq 'true';
	}

	method !string(\json) {
		return json.Str with json;
		return Str;
	}

	method !string-e(\json) {
		return json.Str.trans(['\e', '\a', '\n'] => ["\e", "\a", "\n"]) with json;
		return Str;
	}

	method !cliche(\json) {
		my $name = json<name>;
		die 'Missing cliche\'s name' without $name;
		return LogP6::Cliche.new(
			name => $name,
			matcher => self!matcher(json<matcher>),
			default-pattern => self!string-e(json<default-pattern>),
			default-auto-exceptions => self!bool(json<default-auto-exceptions>),
			default-handle => self!handle(json<default-handle>),
			default-x-pattern => self!string-e(json<default-x-pattern>),
			default-level => self!level(json<default-level>),
			default-first-level-check => self!bool(json<default-first-level-check>),
			grooves => self!list(json<grooves>, 'string'),
			wrapper => self!wrapper(json<wrapper>)
		);
	}

	method !handle(\json) {
		return IO::Handle without json;
		given json<type> {
			when 'std' {
				my $path = json<path>;
				my $result;
				given $path {
					when 'out' {
						$result = $*OUT;
					}
					when 'err' {
						$result = $*ERR;
					}
					default {
						die "Wrong std handle path $path";
					}
				}
				$result.out-buffer = $_ with json<out-buffer>;
				return $result;
			}
			when 'file' {
				my $path = json<path>;
				my $out-buffer = json<out-buffer>;
				die 'Missing file handle path' without $path;
				return self!produce(:use-cache, json, sub {
					my $mode = (json<append> // True) ?? :a !! :w;
					my $handle = $path.IO.open(|$mode, :out-buffer($out-buffer // Nil));
					return $handle;
				});
			}
			when 'custom' {
				return self!custom(json, :use-cache);
			}
			default {
				die "Wrong handle type $_";
				;
			}
		}
	}

	method !any(\json) {
		return self!list(json, 'any') if json ~~ Positional;
		if json ~~ Associative {
			return self!custom(json) if json<type> ~~ 'custom';
			return self!associative(json);
		}
		return json;
	}

	method !associative(\json) {
		return %() without json;
		return Any unless json ~~ Associative;
		my %result = %();
		return json.kv.map(-> $k, $v { $k => self!any($v) }).Hash;
	}

	method !custom(\json, :$use-cache) {
		my \my-require = json<require>;
		die 'Missing \'require\' field in custom definition' without my-require;

		my \fqn-method = json<fqn-method>;
		my \fqn-class = json<fqn-class>;
		die "Missing both 'fqn-method' and 'fqn-class' fields in custom definition"
				if !fqn-method.defined && !fqn-class.defined;
		die "Defined both 'fqn-method' and 'fqn-class' fields in custom definition"
				if fqn-method.defined && fqn-class.defined;

		my \args = self!associative(json<args>);
		die "'args' field are not Associative in cusom definition"
				unless args ~~ Associative;

		return self!produce(:$use-cache, json, sub {
			require ::(my-require);
			with fqn-method {
				my &method = ::(fqn-method);
				return method(|args);
			}
			with fqn-class {
				my $class-name = ::(fqn-class);
				return $class-name.new(|args);
			}
		});
	}

	method !level(\json) {
		return LogP6::Level without json;
		given json {
			when 'trace' { return LogP6::Level::trace; }
			when 'debug' { return LogP6::Level::debug; }
			when 'info'  { return LogP6::Level::info;  }
			when 'warn'  { return LogP6::Level::warn;  }
			when 'error' { return LogP6::Level::error; }
			default { die 'wrong level value ' ~ json; }
		}
	}

	method !matcher(\json) {
		die 'Missing cliche\'s matcher' without json;
		my $matcher = json.Str;
		given $matcher {
			when /^ \/ .+ \/ $/ {
				my $substr = $matcher.substr(1, *-1);
				return / <$substr> /;
			}
			default {
				return $matcher;
			}
		}
	}

	method !wrapper(\json) {
		return LogP6::Wrapper without json;
		given json<type> {
			when 'time' {
				die "Missing 'seconds' field in time wrapper-factory"
						without json<seconds>;
				return self!custom(%(
					:type<custom>,
					:require<LogP6::Wrapper::SyncTime>,
					:fqn-class<LogP6::Wrapper::SyncTime::Wrapper>,
					args =>  %(
						seconds => json<seconds>,
						config-path => json<config-path>
					)
				));
			}
			when 'each' {
				return self!custom(%(
					:type<custom>,
					:require<LogP6::Wrapper::SyncEach>,
					:fqn-class<LogP6::Wrapper::SyncEach::Wrapper>,
					args =>  %(
						config-path => json<config-path>
					)
				));
			}
			when 'transparent' {
				return LogP6::Wrapper::Transparent::Wrapper.new;
			}
			when 'custom' {
				return self!custom(json);
			}
			defined {
				die 'wrong wrapper type value ' ~ json;
			}
		}
	}

	method !produce(\json, &factory, :$use-cache) {
		return factory() unless $use-cache;
		my $key = to-json(json, :sorted-keys);
		with %!previous-cache{$key} {
			%!current-cache{$key} = $_;
			return $_;
		}
		return $_ with %!current-cache{$key};
		my $result = factory();
		%!current-cache{$key} = $result;
		return $result;
	}
}