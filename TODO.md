# TODO
1. ~~add support of '' (default) writers and filters (create them at start)~~
1. ~~add START support (create default)~~
1. ~~add STOP support (close all writers)~~
1. ~~add EXPORT strategy (one for configuring, one for getting)~~
1. ~~logger wrappers and sync~~
1. ~~cliche factories~~
1. ~~improve writer format~~
1. ~~add methods for logger~~
1. ~~add support custom writer (sql or so)~~
1. ~~add support of str format (lazy creation of msg)~~
1. ~~improve logger log method to be more lazy~~
1. ~~improve ndc and mdc logic in Context and Logger (many loggers)~~
1. ~~tests tests tests~~
1. ~~Separate writers and filters and cliches to separate files~~
1. ~~init from file~~
1. ~~sync wrapper from file~~
1. H. docs docs docs
1. H. make logger and pure-logger maps be copy-and-write maps
1. H. make each-time-synchronization wrapper
1. H. improve logic of SyncAbstract wrapper (update logger at the first time and
retap config file each X seconds)
1. M. use a better exceptions instead of 'die'
1. M. add params for %trait in pattern (short, long variant)
1. M. try make entities be really immutable (filters, writes, loggers)
1. L. add 'turn off/on cliche' factory method
1. M.add database writer
1. L. add trace-some methods in logger (like 'returns value', 'enter method with')
1. L. add backup/restore ndc and mdc