unit module LogP6::ConfigFile;

use JSON::Fast;

use LogP6::WriterConf::Std;
use LogP6::FilterConf::Std;
use LogP6::Level;
use LogP6::Logger;
use LogP6::Helpers::LoggerWrapperSyncTime;

sub parce-config(IO() $file-path) is export {
	CATCH {
		default {
			die "Cannot read and create config from file $file-path. Cause "
				~ $_.^name ~ ': ' ~ $_.Str
		}
	}
	my \conf = from-json(slurp($file-path));

	say \conf;
	say list(conf<writers>, &writer);
	say list(conf<filters>, &filter);
	say list(conf<cliches>, &cliche);
	say wrapper-factory(conf<wrapper-factory>);
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
				auto-exceptions => json<auto-exceptions> // Bool
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

sub str(\json) {
	return json.Str;
}

sub cliche(\json) {
	my $name = json<name>;
	die 'Missing cliche\'s name' without $name;
	return LogP6::Cliche.new(
		name => $name,
		matcher => matcher(json<matcher>),
		default-level => level(json<default-level>),
		default-pattern => json<default-pattern> // Str,
		grooves => list(json<grooves>, &str)
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
say 'my-require ', my-require;
say 'my-method ', fqn-method;
say 'args ', args;

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

sub wrapper-factory(\json) {
	return LogP6::LoggerWrapperFactory without json;
	given json<type> {
		when 'time' {
			die 'Missing \'seconds\' field in time wrapper-factory'
				without json<seconds>;
			return LogP6::Helpers::LoggerWrapperFactorySyncTime
					.new(seconds => json<seconds>);
		}
		when 'same' {
			return LogP6::LoggerWrapperFactory;
		}
		when 'custom' {
			return custom(json);
		}
	}
}