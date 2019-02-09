use LogP6::Logger;

class LogP6::Wrapper::SyncAbstract does LogP6::Logger {
	has LogP6::Logger:D $.aggr is required;
	has &.get-fresh-logger is required;

	method sync($context) { ... }

	method get-sync-obj() {
		get-context.sync($!aggr.trait);
	}

	method put-sync-obj($obj) {
		get-context.sync-put($!aggr.trait, $obj);
	}

	method update-aggr() {
		$!aggr = &!get-fresh-logger($!aggr.trait);
	}

	method trait() { $!aggr.trait }
	method ndc-push($obj) { $!aggr.ndc-push($obj) }
	method ndc-pop()      { $!aggr.ndc-pop() }
	method ndc-clean()    { $!aggr.ndc-clean() }
	method mdc-put($key, $obj) { $!aggr.mdc-put($key, $obj) }
	method mdc-remove($key)    { $!aggr.mdc-remove($key) }
	method mdc-clean()         { $!aggr.mdc-clean() }
	method trace(*@args, :$x) { self.sync(get-context); $!aggr.trace(|@args, :$x)}
	method debug(*@args, :$x) { self.sync(get-context); $!aggr.debug(|@args, :$x)}
	method info(*@args, :$x)  { self.sync(get-context);  $!aggr.info(|@args, :$x)}
	method warn(*@args, :$x)  { self.sync(get-context);  $!aggr.warn(|@args, :$x)}
	method error(*@args, :$x) { self.sync(get-context); $!aggr.error(|@args, :$x)}
}
