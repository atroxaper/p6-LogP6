use LogP6::Wrapper;
use LogP6::Logger;
use LogP6::ConfigFile;
use LogP6 :configure;

#| Logger sync wrapper itself
class LogP6::Wrapper::SyncAbstract does LogP6::Logger {
	#| Original logger
	has LogP6::Logger:D $.aggr is required;
	#| Method which used for retrieve the new original logger
	has &.get-fresh-logger is required;

	#|[Chance to synchronize logger.
	#| Subclass can do any action in the method to understand is it need to
	#| retrieve the new original logger or not.]
	method sync($context) { ... }

	#|[Gets an object contains a clue do we need retrieve the new original logger
	#| or not. The object was stored by the logger with the same trait in the same
	#| Thread.]
	method get-sync-obj() {
		get-context.sync($!aggr.trait);
	}

	#|[Store some clue for future. The object can be retrieved by
	#| get-sync-obj method.]
	method put-sync-obj($obj) {
		get-context.sync-put($!aggr.trait, $obj);
	}

	#| Retrieve the new original logger.
	method update-aggr() {
		$!aggr = &!get-fresh-logger($!aggr.trait);
	}

	method !let-sync() {
		self.sync(get-context);
	}

	method trait() { $!aggr.trait }
	method ndc-push($obj) { $!aggr.ndc-push($obj) }
	method ndc-pop()      { $!aggr.ndc-pop() }
	method ndc-clean()    { $!aggr.ndc-clean() }
	method mdc-put($key, $obj) { $!aggr.mdc-put($key, $obj) }
	method mdc-remove($key)    { $!aggr.mdc-remove($key) }
	method mdc-clean()         { $!aggr.mdc-clean() }
	method dc-copy()           { $!aggr.dc-copy }
	method dc-restore($dc)     { $!aggr.dc-restore($dc) }
	method trace(*@args, :$x)  { self!let-sync; $!aggr.trace(|@args, :$x)}
	method tracef(*@args, :$x) { self!let-sync; $!aggr.tracef(|@args, :$x)}
	method debug(*@args, :$x)  { self!let-sync; $!aggr.debug(|@args, :$x)}
	method debugf(*@args, :$x) { self!let-sync; $!aggr.debugf(|@args, :$x)}
	method info(*@args, :$x)   { self!let-sync; $!aggr.info(|@args, :$x)}
	method infof(*@args, :$x)  { self!let-sync; $!aggr.infof(|@args, :$x)}
	method warn(*@args, :$x)   { self!let-sync;  $!aggr.warn(|@args, :$x)}
	method warnf(*@args, :$x)  { self!let-sync; $!aggr.warnf(|@args, :$x)}
	method error(*@args, :$x)  { self!let-sync; $!aggr.error(|@args, :$x)}
	method errorf(*@args, :$x) { self!let-sync; $!aggr.errorf(|@args, :$x)}
	method level($level, *@args, :$x)
		{ self!let-sync; $!aggr.level($level, |@args, :$x) }
	method levelf($level, *@args, :$x)
		{ self!let-sync; $!aggr.levelf($level, |@args, :$x) }
	method trace-on() { self!let-sync; $!aggr.trace-on() }
	method debug-on() { self!let-sync; $!aggr.debug-on() }
	method info-on()  { self!let-sync; $!aggr.info-on() }
	method warn-on()  { self!let-sync; $!aggr.warn-on() }
	method error-on() { self!let-sync; $!aggr.error-on() }
	method level-on($level) { self!let-sync; $!aggr.level-on($level) }
}

#|[Wrapper logic for synchronize a configuration and a logger.
#| It registers a file watcher on a configuration file for see all changes
#| in the file.]
class LogP6::Wrapper::SyncAbstract::Wrapper does LogP6::Wrapper {
	#| Path for configuration file to watch
	has $.config-path;

	method wrap(LogP6::Logger:D $logger --> LogP6::Logger:D) { ... }

	submethod TWEAK() {
		# try to use specified path or default one
		my $path = $!config-path && $!config-path.trim;
		$path = $path.Bool && $path.IO.e ?? $path !! Any;
		$path //= default-config-path();
		return without $path;

		my $tap;
		$tap = IO::Notification.watch-path($path).act( -> $change {
			$tap.close;
			init-from-file($path);
		});
	}
}
