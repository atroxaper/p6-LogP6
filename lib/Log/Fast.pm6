use Log::Fast::Layout 'Layout';
use Log::Fast::Writer 'Writer';
use Log::Fast::Logger 'Logger';

class Log::Fast {

	my Lock $lock .= new;
	my $writers =
		%(root => Log::Fast.writer(:name<root>, :layout('%d %l %m'), io => $*OUT, :c));
	my $loggers = %();

	method writer(
		Log::Fast:U: Str:D :$name!, Str:D :$layout, IO::Handle:D :$io,
		Bool :$c, Bool :$u, Bool :$d
	) {
		$lock.protect({
			if $d {
				my $w = ⚛$writers;
				my $removed = $w{$name}:delete;
				with $removed {
					my %l = ⚛$loggers;
					my $the-new =%();
					for %l.kv -> $name, $logger {
						$the-new{$name} = $logger.minus-writers($removed);
					}
					$loggers ⚛= $the-new;
				}
				$writers ⚛= $w;
				return $removed; # todo: add .close to the documentation
			} elsif $u {

			} elsif $c {
				my $w = ⚛$writers;
				die 'todo: add exception' with $w{$name};
				my $the-new = Writer.new(:$name, :$io, layout => Layout.new(:str($layout)));
				$w{$name} = $the-new;
				$writers ⚛= $w;
				return $the-new;
			} else {
				die 'todo: add exception';
			}
		});
	}

	has Str:D $.name is required;
	has Str:D $.level is required;
	has Positional $filters;

	our sub get-log(Str:D $name = 'say' --> Log::Fast:D) is export {
		say $?CLASS.^name;
		say $?PACKAGE;
#		say $?MODULE;
		return Log::Fast.new: :$name;
	}

	my class Config {
		has Str $!level;
		has IO::Handle $!io;
		has Str $!layout;
		has @!filters-first;
	}

	my class Pipeline {
		has @!filters-first;
		has @!layout-parts;
		has @!filters-second;
	}
}