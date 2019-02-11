unit module LogP6::ConfigFile;

use JSON::Fast;

use LogP6::WriterConf::Std;
use LogP6::FilterConf::Std;
use LogP6::Level;
use LogP6::Cliche;
use LogP6::Wrapper::SyncTime;
use LogP6::Wrapper::Transparent;

class LogP6::Config {
	has $.writers;
	has $.filters;
	has $.cliches;
	has $.default-pattern;
	has $.default-auto-exceptions;
	has $.default-handle;
	has $.default-x-pattern;
	has $.default-level;
	has $.default-first-level-check;
	has $.default-wrapper;
}

sub parce-config(IO() $file-path) is export {
	CATCH {
		default {
			die "Cannot read and create config from file $file-path. Cause "
							~ $_.^name ~ ': ' ~ $_.Str
		}
	}
	my $file-content = slurp($file-path).trim;
	die "config file $file-path is empty" if $file-path.chars == 0;
	my \conf = from-json($file-content);

	return LogP6::Config.new(
			writers => list(conf<writers>, &writer),
			filters => list(conf<filters>, &filter),
			cliches => list(conf<cliches>, &cliche),
			default-pattern => string(conf<default-pattern>),
			default-auto-exceptions => bool(conf<default-auto-exceptions>),
			default-handle => handle(conf<default-handle>),
			default-x-pattern => string(conf<default-x-pattern>),
			default-level => level(conf<default-level>),
			default-first-level-check => bool(conf<default-first-level-check>),
			default-wrapper => wrapper(conf<default-wrapper>)
	);
}

sub list(\json, &each) {
	return () without json;
	return json.map({each($_)}).list;
}

sub writer(\json) {
	given json<type> {
		when 'std' {
			return LogP6::WriterConf::Std.new(
				name => json<name> // Str,
				pattern => json<pattern> // Str,
				handle => handle(json<handle>),
				auto-exceptions => bool(json<auto-exceptions>)
			);
		}
		when 'custom' {
			return custom(json);
		}
		default {
			die "Wrong writer type $_";
		}
	}
	json<args><name>.Str;
}

sub filter(\json) {
	given json<type> {
		when 'std' {
			return LogP6::FilterConf::Std.new(
				name => json<name> // Str,
				level => level(json<level>),
				first-level-check => json<first-level-check> // Bool,
				before-check => list(json<before-check>, &custom),
				after-check => list(json<after-check>, &custom)
			);
		}
		when 'custom' {
			return custom(json);
		}
		default {
			die "Wrong filter type $_";
		}
	}
	json<args><name>.Str;
}

sub bool(\json) {
	return Bool without json;
	return json if json ~~ Bool;
	return json eq 'true';
}

sub string(\json) {
	return json.Str with json;
	return Str;
}

sub cliche(\json) {
	my $name = json<name>;
	die 'Missing cliche\'s name' without $name;
	return LogP6::Cliche.new(
		name => $name,
		matcher => matcher(json<matcher>),
		default-pattern => string(json<default-pattern>),
		default-auto-exceptions => bool(json<default-auto-exceptions>),
		default-handle => handle(json<default-handle>),
		default-x-pattern => string(json<default-x-pattern>),
		default-level => level(json<default-level>),
		default-first-level-check => bool(json<default-first-level-check>),
		grooves => list(json<grooves>, &string),
		wrapper => wrapper(json<wrapper>)
	);
}

sub handle(\json) {
	return IO::Handle without json;
	given json<type> {
		when 'std' {
			my $path = json<path>;
			given $path {
				when 'out' {
					return $*OUT;
				}
				when 'err' {
					return $*ERR;
				}
				default {
					die "Wrong std handle path $path";
				}
			}
		}
		when 'file' {
			my $path = json<path>;
			die 'Missing file handle path' without $path;
			my $append = json<append>;
			my $not-append = ($append eqv False);
			return $path.IO.open(:create, append => !$not-append);
		}
		when 'custom' {
			return custom(json);
		}
		default {
			die "Wrong handle type $_";;
		}
	}
}

sub custom(\json) {
	my \my-require = json<require>;
	my \fqn-method = json<fqn-method>;
	my \args = json<args> // %();
	die 'Missing \'require\' field in custom definition' without my-require;
	die 'Missing \'fqn-method\' field in custom definition' without fqn-method;
	die '\'Args\' field are not Associative in cusom definition'
		unless args ~~ Associative;

	require ::(my-require);
	my &method = ::(fqn-method);
	return method(|args);
}

sub level(\json) {
	return LogP6::Level without json;
	given json {
		when 'trace' { return trace; }
		when 'debug' { return debug; }
		when 'info'  { return info;  }
		when 'warn'  { return warn;  }
		when 'error' { return error; }
		default { die 'wrong level value ' ~ json; }
	}
}

sub matcher(\json) {
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

sub wrapper(\json) {
	return LogP6::Wrapper without json;
	given json<type> {
		when 'time' {
			die 'Missing \'seconds\' field in time wrapper-factory'
				without json<seconds>;
			return LogP6::Wrapper::SyncTime::Wrapper
					.new(seconds => json<seconds>);
		}
		when 'transparent' {
			return LogP6::Wrapper::Transparent::Wrapper.new;
		}
		when 'custom' {
			return custom(json);
		}
		defined {
			die 'wrong wrapper type value ' ~ json;
		}
	}
}