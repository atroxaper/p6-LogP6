[![Build Status](https://travis-ci.org/atroxaper/p6-LogP6.svg?branch=master)](https://travis-ci.org/atroxaper/p6-LogP6)

# NAME

LogP6 - full customisable and fast logging library inspired by idea of separate
a logging and its configuration. You can use it not only in apps but
even in your own libraries.

# TABLE OF CONTENTS

- [NAME](#name)
- [SYNOPSIS](#synopsis)
- [DESCRIPTION](#description)
	- [Features](#features)
	- [Concepts](#concepts)
	- [Example](#example)
	- [Context](#context)
	- [Writer](#writer)
	- [Filter](#filter)
	- [Nested Diagnostic Context (NDC) and Mapped Diagnostic Context (MDC)](#nested-diagnostic-context-ndc-and-mapped-diagnostic-context-mdc)
	- [Logger](#logger)
	- [Logger Wrapper](#logger-wrapper)
		- [Synchronisation of configuration and Logger instance](#synchronisation-of-configuration-and-logger-instance)
- [CONFIGURATION](#configuration)
	- [Logger retrieve](#logger-retrieve)
	- [Factory subroutines](#factory-subroutines)
	- [Configuration file](#configuration-file)
	- [Writer configuration](#writer-configuration)
		- [WriterConf](#writerconf)
		- [Standard WriterConf](#standard-writerconf)
		- [Pattern](#pattern)
		- [Writer factory subroutines](#writer-factory-subroutines)
		- [Writer configuration file](#writer-configuration-file)
	- [Filter configuration](#filter-configuration)
		- [FilterConf](#filterconf)
		- [Standard FilterConf](#standard-filterconf)
		- [Filter factory subroutines](#filter-factory-subroutines)
		- [Filter configuration file](#filter-configuration-file)
	- [Defaults](#defaults)
		- [Defaults factory subroutines](#defaults-factory-subroutines)
		- [Defaults configuration file](#defaults-configuration-file)
	- [Cliche](#cliche)
		- [Cliche factory subroutines](#cliche-factory-subroutines)
		- [Cliche configuration file](#cliche-configuration-file)
	- [Default logger](#default-logger)
	- [Change configuration](#change-configuration)
- [EXAMPLES](#examples)
	- [Use external library witch uses LogP6](#use-external-library-witch-uses-logp6)
	- [Change console application verbosity level](#change-console-application-verbosity-level)
	- [Associate logs with concrete user](#associate-logs-with-concrete-user)
	- [Filter log by its content](#filter-log-by-its-content)
	- [Write one log in several outputs](#write-one-log-in-several-outputs)
- [BEST PRACTICE](#best-practice)
- [ROADMAP](#roadmap)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# SYNOPSIS

Logger system have to be as much transparent as possible. At the same time it
have to be fully customisable. It have to provide possibility to change logging
logic without changing any line of code. It is amazing if you can use logger
system during developing a library and its user do not feel discomfort of it.
`LogP6` logger library is all about that.

# DESCRIPTION

## Features

1. Possibility to change logger configuration and its behaviour without touching
the code;
2. Configuring from the code and/or configuration files;
3. Possibility to use any kind of IO::Handler, even for async or database work;
4. Possibility to use multiple loggers in one app;
5. Possibility to use multiply IO::Handler's in one logger;
6. Flexible filter system;
7. Stack and Map entities associated with each thread and possibility to use
values from it in the logger;
8. Pretty fast work. Using pre-calculation as much as it can be done - parse
logger layout pattern only once, reuse current DateTime objects and so on; 
9. Possibility to use logger while development (dynamically change logger
settings in runtime), and while production work (maximum fast, without any lock
excepts possible IO::Handle implementation's).

## Concepts

- `writer` - an object which know how and where logs must be written. In
simple case - which file and string format pattern will be used;
- `filter` - an object which know which logs must be written. In simple case -
logs with which levels are allowed to pass to the `writer`;
- `cliche` - template for creating `Logger`. Contains writers, filters and other
configurations for future Loggers;
- `logger` - instance created using configuration from the `cliche`. Just logger
with standard functionality like `info()` method;
- `logger trait` - string value describes semantic purpose of concrete Logger.
For example, the name of class where the logger is used or the type of logged
information (for example, 'internal-audit-subsystem'). `LogP6` uses `trait` for
create the new or get already created logger;
- `cliche's matcher` - special field of the cliche. The field may be a literal
string or regex. If the logger `trait` satisfies the `matcher` then the cliche
will be used for creating the logger with the trait;
- `context` - associated with each Thread object which contains information
for logging like your final log message, exception you specified, log level,
current date, thread name and so on. Context can be used for storing some
specific information you and `LogP6` library need while logging.

## Example

Using logger:
```perl6
use LogP6;                     				# use library in general mode

my \log = get-logger('audit'); 				# create or get logger with 'audit' trait
log.info('property ' ~ 'foo' ~ ' setted as ' ~ 5); 	# log string with concatenation
log.info('property %s setted as %d', 'foo', 5);    	# log sprintf like style
```

Configure the logger in code:
```perl6
use LogP6 :configure;   # use library in configure mode
cliche(                 # create a cliche
  :name<cl>,            # obligatory unique cliche name
  :matcher<audit>,      # obligatory matcher
  grooves => (                                          # optional list of writer-filter pairs (or their names)
    writer(:pattern('%level| %msg'), :handle($*ERR)),   # create anonymous (w/o name) writer configuration
    filter(:level($debug))));                           # create anonymous (w/o name) filter configuration
```

Configure in the configuration file style (same as above):
```json
{
  "writers": [{
    "type": "std",
    "name": "w",
    "pattern": "%level | %msg",
    "handle": { "type": "std", "path": "err" }
  }],
  "filters": [{
    "type": "std",
    "name": "f",
    "level": "debug"
  }],
  "cliches": [{
    "name": "cl",
    "matcher": "audit",
    "grooves": [ "w", "f" ] 
  }]
}
```

## Context

LogP6 library adds an object associated with each Thread - `Logger Context` or
just `context`. You can work with the context directly in `filter` subsystem
or in custom `writer` implementations. Also `logger` has special methods
for working with `NDC` and `MDC` (see below in [Logger](#logger)). For more
information please look at methods' declarators in `LogP6::Context`.

## Writer

`Writer` is responsible to write all corresponding data to corresponding output
in some format. It has only one method: 

- `write($context){...}` - this method have to take all necessary data from the
specified `context` and use it for writing. Note: the specified context will
change its data after method call. Do not cache the context itself (for example
for asynchronous writing) but only its data.

## Filter

`Filter` is responsible to decide allow the corresponding `writer` to write log
or not. It has three methods:

- `do-before($context){...}` - some code which decides allow log to be pass to
the writer or not. If it returns True then the log will be pass to the writer.
Otherwise the log will be discarded.
- `reactive-level(){}` - in most cases filtering can be done only by log level.
This method returns a log level which allows logger to call `do-before` method.
If filtering log's level importance is less then returned reactive level then
the log will be discarded without calling `do-before` method.
- `do-after($context){}` - any code which have to be executed after the writer
work in case when `do-before` method returns True.

## Nested Diagnostic Context (NDC) and Mapped Diagnostic Context (MDC)

There are cases when we want to trace some information through group of log
messages, but not only in one message. For example, user id, http session
number or so. In such cases we have to store the information somewhere, pass
it through logic subs and methods and pass to log methods over and over again.
Since log system have to be separated from the main program logic then we need a
special place to store the information. That place is a
`Nested Diagnostic Context` (`NDC`) - a stack structure and a
`Mapped Diagnostic Context` (`MDC`) - a map structure. You can push/pop values
in `NDC` and put/remove values in `MDC`. Standard writer has special
placeholders for message pattern (see below in [Pattern](#pattern)) for put all
values from `NDC` or some kay associated value from `MDC` to final log message
string.

## Logger

The logger is an immutable object that contains from zero to several pairs of 
`writer` and `filter` (`grooves`). For each time the you want to log some
message (with or without arguments) the logger compiles message+arguments in
one message string, updates the `context` and goes through `grooves` - call
filter's methods and if it pass then ask a writer to write message. The writer
takes all necessary information such as message, log level, NDC/MDC values,
current date-time and so from the context.

Logger has the following methods:

- `trait()` - returns logger trait;
- `ndc-push($obj)`, `ndc-pop()`, `ndc-clean()` - work with NDC;
- `mdc-put($key, $obj)`, `mdc-remove($key)`, `mdc-clean()` -  work with MDC;
- `trace(*@args, :$x)`, `debug(*@args, :$x)`, `info(*@args, :$x)`,
`warn(*@args, :$x)`, `error(*@args, :$x)` - logging the arguments with specified
importance log level. `:$x` is an optional exception argument. `@args` - data
for logging. If the array has more then one element then the first element is
used as format for `sprintf` sub and the rest elements as `sprintf` args;

## Logger Wrapper

System to wrap (or decorate) logger object into another and add additional
logic. You can describe `logger wrapper factory` which will wrap any created
`logger`.

### Synchronisation of configuration and Logger instance

An example of logger wrapper usage is synchronisation a logger configuration
and logger instance. It may be useful in case of development or debug session
to change logger configuration dynamically.

Since a logger object are immutable and cannot know about changes in
configuration it produced, we need a logic which checks if user updated
corresponding configuration and updates the logger instance.

You can specify any kind of wrapper for logger synchronization. There are
helper class `LogP6::Wrapper::SyncAbstract` to create your own synchronization
wrapper.

For now there is only two synchronization wrappers:

- `LogP6::Wrapper::SyncTime::Wrapper` - checks the new configuration change each
`X` seconds;
- `LogP6::Wrapper::SyncEach::Wrapper` - checks the new configuration change each
time you use logger.

# CONFIGURATION

For working with `LogP6` library you need to `use LogP6;` module. Without any
tags it provides only `get-logger($trait)` sub for retrieving a logger.
`:configure` tag provides factory subroutines for configuring loggers from the code.
Another option to configure logger is using configuration file.

## Logger retrieve

For retrieve a logger you need to use `LogP6` module and call
`get-logger($trait)` sub with logger trait you need. Example:

```perl6
use LogP6;

my $log = get-logger('main');
# using $log ...
```

If you did not configure a `Cliche` for specified logger trait ('main' in
the example), the default logger will be returned (see 
[Default logger](#default-logger)). In other case the logger created by the
cliche with matcher the trait satisfy will be returned.

## Factory subroutines

`LogP6` provides subroutines for configure loggers from the code dynamically.
To get access to them you need to `use LogP6` with `:configure` tag. There are 
subroutines for configuring `filters`, `writers`, `cliches` and any default
values like `writer pattern`, `logger wrapper` or so. Concrete subroutines will
be described in corresponding sections below. There is `get-logger-pure($trait)`
sub for retrieve pure logger without any wrappers. Also five variables for five
`LogP6::Level` enum values are exported as `$trace`, `$debug`, `$info`, `$warn`
and `$error`. Example:

```perl6
use LogP6 :configure;

set-default-wrapper(LogP6::Wrapper::SyncTime::Wrapper.new(:60seconds)); # set default wrapper
set-default-level($debug);    # set default logger level as debug
my $log = get-logger('main'); # get wrapped logger
$log.debug('msg');
my $pure-log = get-logger-pure('main'); # this logger will not synchronize its configuration
```

## Configuration file

Better alternative (especially for production using) of configuration by factory
subroutines is configuration file. You can specify path to it through
`LOG_P6_JSON` system environment variable. In case the variable is empty then
standard path `./log-p6.json` will be used (if it exists). Or you can initialize
`LogP6` library using `init-from-file($config-path)` factory subroutine.

Configuration file is `json` formatted file. Example:

```json
{
  "default-pattern": "%msg",
  "default-level":  "trace",
  "default-handle": { "type": "std", "path": "err" },
  "writers": [{ "type": "std", "name": "w" }],
  "filters": [{ "type": "std", "name": "f" }],
  "cliches": [{ "name": "c2", "matcher": "main" }]
}
```
Concrete format for concrete objects will be described in corresponding
sections below.

Some object like `writers`, `wrappers` or so have a `type` filed. Each object
has its own list of available types. There are type which can be used in any 
object - `custom`. It uses to describe factory method or class which will be
used to produce the object. It requires additional fields:
- `require` - name of module with factory method or class;
- `fqn-method` or `fqn-class` - full qualified name of method or class in
`require` module;
- `args` - list of named arguments which will be passed to `fqn-method()` or
`fqn-class.new()`.

For example, creating IO::Handle by `create-handle` subroutine in `MyModule`
with arguments `:path<out.txt>, :trait<rw>`:

```json
{
  "default-handle": {
    "type": "custom",
    "require": "MyModule",
    "fqn-method": "MyModule::EXPORT::DEFAULT::&create-handle",
    "args": { "path": "out.txt", "trait": "rw" }
  }
}
``` 

## Writer configuration

### WriterConf

`WriterConf` is a configuration object which contains all necessary information
and algorithm for creating a concrete `writer` instance. For more
information please look at methods' declarators in `LogP6::WriterConf`.
	
### Standard WriterConf

Standard `WriterConf` (`LogP6::WriterConf::Std`) makes a writer which writes log
message to abstract `IO::Handle`. It has a `pattern` - string with special
placeholders for values like `ndc`, current `Thread` name, log message and so.
`Writer` will put all necessary values into `pattern` and write it to handle.
Also standard `WriterConf` has boolean `auto-exceptions` property - if it is
`True` then placeholder for exception will be concatenated to the `pattern`
automatically. Form of the exception placeholder can be configured separately
(see [Defaults](#defaults) and [Cliche](#cliche)).

### Pattern

Pattern placeholders starts with `%` symbol following placeholder name. If
placeholder has arguments they can be passed in curly brackets following
placeholder name.
 
Pattern can has the following placeholders:

- `%trait` - for name of logger trait;
- `%tid` - for current `Thread` id;
- `%tname` - for current `Thread` name;
- `%msg` - for log message;
- `%ndc` - for full NDC array joined by space symbol;
- `%mdc{obj_key}` - for MDC value with `obj_key` key;
- `%x{$msg $name $trace}` - for exception. String in curly brackets is used as
subpattern. `$msg` - optional exception message, `$name` - optional exception
name, `$trace` - optional exception stacktrace. For example,
`'%x{($name "$msg") Trace: $trace}'` can be converted into
`'(X::AdHoc "test exception") Trace: ...'`;
- `%level{WARN=W DEBUG=D ERROR=E TRACE=T INFO=I length=2}` - log importance
level. By default logger will use level name in upper case but you can
specify synonyms for all or part of them in curly brackets in format
`<LEVEL_NAME>=<sysnonym>`. Also you can specify a length of log level name.
Default length is 5. For example `'[%level{WARN=hmm ERROR=alarm length=5}]'` can
be converted into `'[hmm  ]'`, `'[alarm]'`, `'[INFO ]'`, `'[DEBUG]'`;
- `%date{$yyyy-$yy-$MM-$MMM-$dd $hh:$mm:$ss:$mss $z}` - current date and time.
String in curly brackets is used as
subpattern.
	- `$yyyy`, `$yy` - year in 4 and 2 digits format;
	- `$MM`, `$MMM` - month in 2 digits and short name format;
	- `$dd` - day in 2 digits format;
	- `$hh`, `$mm`, `$ss`, `$mss` - hours, minutes, seconds and milliseconds
	- `$z` - timezone

### Writer factory subroutines

`LogP6` module has the following subs for manage writers configurations:

- `get-writer(Str:D $name --> LogP6::WriterConf)` - gets writer with specified
name;
- `writer(:$name, :$pattern, :$handle, :$auto-exceptions, :create, :update, :replace --> LogP6::WriterConf)` -
create, update or replace standard `WriterConf` with specified name. If you want
to `:update` only concrete fields in already created configuration then the rest
fields will not be changed. In case of `:replace` the new configuration will be
created and replaced the old one. You can create configuration without name -
then the configuration will not be stored, but only returned to you. The method
returns the old writer configuration (`:update`, `:replace`) and the new one
(`:create`);
- `writer(LogP6::WriterConf:D $writer-conf, :create, :replace --> LogP6::WriterConf)` -
save or replace any implementation of `WriterConf`. The configuration name
will be retrieved from the `$writer-conf`. The method returns the old writer
configuration (`:replace`) and the new one (`:create`);
- `writer(:$name, :$remove --> LogP6::WriterConf)` - remove and return a
configuration with specified name.

### Writer configuration file

In configuration file writer configurations have to be listed in `writers`
array. Only `std` (for standard configuration) and `custom` types are supported.

In case of standard configuration all field are optional excepts `name`. Handle
can be:

- `file` type for output into file. You can specify `path` and `append`
arguments;
- `std` type for output into `$*OUT` or `$*ERR`. You can specify `path` as `out`
or `err`.
- `custom` type.

In case of `custom` writer type the result writer configuration have to returns
not empty name.

Example:

```json
{
  "writers": [
    {"type": "std", "name": "w1", "pattern": "%msg", "handle": {"type": "std", "path": "out"}},
    {"type": "std", "name": "w2", "handle": {"type": "file", "path": "log.txt", "append": false}},
    {"type": "custom", "require": "Module", "fqn-method": "Module::EXPORT::DEFAULT::&writer", "args": { "name": "w3" }}
  ]
}
```

## Filter configuration

### FilterConf

`Filter` creates by `FilterConf` - a configuration object which contains all
necessary information and algorithm for creating a concrete `filter` instance.
For more information please look at methods' declarators in `LogP6::FilterConf`.

### Standard FilterConf

Standard `FilterConf` (`LogP6::FilterConf::Std`) has array for `do-before` subs
and array for `do-after` subs. `Filter` made by standard `FilterConf` calls 
each `do-before` sub and stop at the first `False` returned value. If all
`do-before` subs returned `True`, then the filter's `do-before` method returns
`True`. The `do-after` work in the same way. Also there is `first-level-check`
property. If it set to `True` then the sub for checking log level will be added
automatically as the first element in `do-before` array; if the property set to
`False` then the sub will be added automatically as the last element in
`do-before` array.

### Filter factory subroutines

`LogP6` module has the following subs for manage filters configurations:

- `get-filter(Str:D $name --> LogP6::FilterConf)` - gets filter with specified
name
- `filter(:$name, :$level, :$first-level-check, List :$before-check, List :$after-check, :create, :update, :replace --> LogP6::FilterConf)` -
create, update or replace standard `FilterConf` with specified name. If you want
to `:update` only concrete fields in already created configuration then the rest
fields will not be changed. In case of `:replace` the new configuration will be
created and replaced the old one. You can create configuration without name -
then the configuration will not be stored, but only returned to you. The method
returns the old filter configuration (`:update`, `:replace`) and the new one
(`:create`);
- `level($level --> LogP6::FilterConf:D)` - the short form for
`filter(:level($level), :create)`;
- `filter(LogP6::FilterConf:D $filter-conf, :create, :replace)` -
save or replace any implementation of `FilterConf`. The configuration name
will be retrieved from the `$filter-conf`. The method returns the old filter
configuration (`:replace`) and the new one (`:create`);
- `filter(:$name, :$remove)` - remove and return a configuration with specified
name.

### Filter configuration file

In configuration file filter configurations have to be listed in `filters`
array. Only `std` (for standard configuration) and `custom` types are supported.

In case of standard configuration all field are optional excepts `name`.
`before-check` and `after-check` are arrays with `custom` typed elements.

In case of `custom` filter type the result filter configuration have to returns
not empty name.

Example:

```json
{
  "filters": [
    {"type": "std", "name": "f1", "level": "error", "first-level-check": false},
    {"type": "std", "name": "f2", "level": "info", "before-check": [{ "require": "MyModule", "fqn-method": "MyModule::EXPORT::DEFAULT::&before-check" }]},
    {"type": "custom", "require": "MyModule", "fqn-class": "MyModule::MyFilter", "args": { "name": "f3" }}
  ]
}
```

## Defaults

Standard filters and writers has fields and options which affect their work.
Some of them you can specify in factory subroutines or configuration file
fields. If such arguments are omitted then the default values of it will be
used. Another fields and options cannot be setter this way. For example, pattern
for exception which will be concatenated to main pattern in standard writer when
`auto-exceptions` sets to `True`
(see [Standard WriterConf](#standard-writerconf)). Such properties have default
values too. All the defaults can be set through factory subroutines or fields in
configuration file.

Configuring default values are useful in case you what to avoid many boilerplate
configurations.

### Defaults factory subroutines

There are the following factory subs for set defaults values:

- `set-default-pattern(Str:D $pattern)` - set default pattern for standard
`WriterConf`. Default value is `'[%date{$hh:$mm:$ss}][%level{length=5}] %msg'`;
- `set-default-auto-exceptions(Bool:D $auto-exceptions)` - set default
`auto-exceptions` property value for standard `WriterConf`. Default value is
`True`;
- `set-default-handle(IO::Handle:D $handle)` - set default handle for standard
`WriterConf`. Default value is `$*OUT`;
- `set-default-x-pattern(Str:D $x-pattern)` - set pattern for exception which
will be concatenated to the main pattern in standard `WriterConf` in case
`auto-exceptions` sets to `True`
(see [Standard WriterConf](#standard-writerconf)). Default value is
`'%x{ Exception $name: $msg' ~ "\n" ~ '$trace}'`
- `set-default-level(LogP6::Level:D $level)` - set default level for standard
`WriterConf`. Default value is `LogP6::Level::error`;
- `set-default-first-level-check(Bool:D $first-level-check)` - set default value
of `first-level-check` property of standard `FilterConf`
(see [Standard FilterConf](#standard-filterconf)). Default value is `True`;
- `set-default-wrapper(LogP6::Wrapper $wrapper)` - set wrapper for loggers
(see [Logger Wrapper](#logger-wrapper)). Default value is
`LogP6::Wrapper::Transparent::Wrapper.new`.

### Defaults configuration file

You can configure default values in configuration file through the following
json fields of a root object:

- `"default-pattern": <string>` - for default pattern for writers with `std`
type;
- `"default-auto-exceptions": <boolean>` - for default `auto-exceptions` field
value for writers with `std` type;
- `"default-handle": <handle>` - for default handle for writers with `std` type;
- `"default-x-pattern": <string>` - for default exceptions pattern for writers
with `std` type;
- `"default-level": <level-name>` - for default level for filters with `std`
type;
- `"default-first-level-check": <boolean>` - for `first-level-check` value for
filters with `std` type;
- `"default-wrapper": <wrapper>` - for wrapper for loggers.

`Wrapper` can be:

- `time` type for `LogP6::Wrapper::SyncTime::Wrapper`. It takes obligatory
`"seconds": <num>` and optional `"config-path": <string>` addition fields;
- `each` type for `LogP6::Wrapper::EachTime::Wrapper`. It takes optional
`"config-path": <string>` addition field;
- `transparent` type for `LogP6::Wrapper::Transparent::Wrapper`;
- `custom` type.

## Cliche

`Cliche` is a template for creating Logger. Each `cliche` has
`cliche's matcher` - literal or regex field. When you what to get logger for
some `logger trait` then logger system try to find a `cliche` with `matcher` the
`trait` satisfies (by smartmatch). If there are more then one such cliche
then the most resent created will be picked. The picked `cliche`'s content will
be used for creating the new logger.

Cliche contains writers and filters configurations pairs called `grooves` and
own `defaults` values which overrides global `defaults` values
(see [Defaults](#defaults)). You can use the same writer and/or filter in
several `grooves`. It the `grooves` list is empty or missed the created logger
will drop the all logs you pass to it;

### Cliche factory subroutines

`LogP6` module has the following subs for manage cliches configurations:

- `cliche(:$name!, :$matcher!, Positional :$grooves, :$wrapper, :$default-pattern, :$default-auto-exceptions, :$default-handle, :$default-x-pattern, :$default-level, :$default-first-level-check, :create, :$replace)` -
create or replace cliche with specified name and matcher. All passed `defaults`
overrides globals `defaults` in withing the cliche. `$grooves` is a
`Positional` variable with alternating listed `writers` and `filters`. 
`$grooves` will be flatted before analyze - you can pass into it a list of two
elements lists or any structure you want. Elements of `$grooves` can be either
a names of already stored writers and filters, already stored writers and
filters with names or writers and filters without names. In the last case
the writer or filter will be stored with generated UUID name automatically.
The method returns the old cliche (`:replace`) and the new one (`:create`);
- `cliche(LogP6::Cliche:D $cliche, :create, :replace)` - save or replace
cliche;
- `cliche(:$name!, :remove)` - remove and return a cliche with specified name.

### Cliche configuration file

In configuration file cliches have to be listed in `cliches` array. It has the
following fields:

- `"name": <string>` - obligatory name of cliche;
- `"matcher": <string>` - cliche matcher. If the matcher value start and ends
with `/` symbol then the matcher is interpreted as regex; in other case it is a
literal;
- `"grooves": [<writer1-name>, <filter1-name>, <writer2-name>, <filter2-name>, ... ]` -
grooves, list of writers' and filters' names;
- defaults - the same fields with the same possible values as described in
[Defaults configuration file](#defaults-configuration-file) excepts
`default-wrapper` - you need to use `wrapper` field name.

Example:

```json
{
  "cliches": [{
    "name": "c1", "matcher": "/bo .+ om/", "grooves": [ "w1", "f1", "w2", "f1" ],
    "wrapper": { "type": "transparent" }, "default-pattern": "%level %msg"
  }]
}
```

## Default logger

In any way you configured your cliches by the factory routines or configuration
file or did not use non of them the `default cliche` will be in the logger
library. Default cliche corresponds the following configuration:
`cliche(:name(''), :matcher(/.*/), grooves => (writer(:name('')), filter(:name(''))))`.
In another words, default cliche has empty string name, matches any trait, has
only one groove with empty (uses all defaults) writer with empty string name and
with empty (uses all defaults) filter with empty string name. It means,
by default you do not need to configure nothing at all. But you can change the
default cliche or default writer and filter by factory subroutines or in
configuration file. Note that if `LogP6` library will not find cliche with
matcher logger trait satisfies then an exception will be thrown.

## Change configuration

Sometimes you may need to change logger configuration in runtime execution. It
can be simply done by factory subroutines. After calling any factory subroutine
all loggers for already used `logger traits` will be recreated and you can get
it by `get-logger($trait)` sub. If your already got logger use
synchronisation wrapper then the wrapper will sync the logger himself correspond
its algorithm.

Another way of change configuration is using configuration file modification.
Changes in configuration file will be detected only if you already using any of
synchronisation wrapper (in `defaults` or in one of `cliches`). After any
change detection all already configured configuration will be dropped and
created the new from the file.

# EXAMPLES

Lets explore a few general use cases:

## Use external library witch uses LogP6

`LogP6` can be used during library development and a user of the library wants
fully turn off any logs from the library. Lets imagine that all libraries
loggers traits starts with `LIBNAME` letters. In such case we can create a
`cliche` with corresponding `matcher` and empty `grooves` - all library logs
will be dropped.

In `Perl 6`:

```perl6
use LogP6 :configure;

cliche(:name('turn off LIBNAME'), :matcher(/^LIBNAME .*/), :wrapper(LogP6::Wrapper::Transparent::Wrapper.new));
```

Or in configuration file:

```json
{ "cliches": [{"name": "turn off LIBNAME", "matcher": "/^LIBNAME .*/", "wrapper": {"type": "transparent"}}] }
```

We use wrapper without synchronisation (transparent) because we do not plan to
change configuration for the library loggers.

## Change console application verbosity level

Lets imagine we are writing console application and we want to add flag
`--verbose` for getting more detail output. Lets using special logger in purpose
of application console output instead of using simple `say` and change filter
level according user's choice:

In `Perl 6`:

```perl6
use LogP6 :configure;

cliche(:name<output>, :matcher<say>, grooves => (writer(:pattern('%msg'), :handle($*OUT)), filter(:name<verbosity>, :level($info))));

sub MAIN(Bool :$verbose) {
  filter(:name<verbosity>, :level($debug), :update) if $verbose;
  my $say = get-logger('say');
  $say.info('Greetings');
  $say.debug('You set verbose flag to %s value', $verbose);
}
```

In that case we do not need to use configuration file. But if you want then you
can remove line with `cliche` creation and add the following configuration file:

```json
{
  "writers": [{ "type": "std", "name": "say", "pattern": "%msg", "handle": { "type": "std", "path": "out" }}],
  "filters": [{ "type": "std", "name": "verbosity", "level": "info"}],
  "cliches": [{ "name": "output", "matcher": "say", "grooves": [ "say", "verbosity" ]}]
}
```

## Associate logs with concrete user

Lets imagine we write a server application. Many users at the same time can
connect to the server and do some action which produces log messages in log
file. If some exception will be caught and log we want to reconstruct user's
execution flow to understand what went wrong. But needful logs in log file will
be alongside with logs from other users actions. In such cases we need to
associate each log entry with some user id. Then we just can grep log file for
the user id. For that just use `MDC`.

In `Perl 6`:

```perl6
use LogP6 :configure;

cliche(:name<logfile>, :matcher<server-log>, grooves => (
  writer(
    :pattern('[%date{$hh:$mm:$ss:$mss}][user:%mdc{user-id}]: %msg'),
    :handle('logfile.log'.IO.open)),
  level($info)
));

my $server-log = get-logger('server-log');

sub database-read() { # note we do not pass $user in the sub
  $server-log.info('read from database'); # [23:35:43:1295][user:717]: read from database
  # read
  CATCH { default {
    $server-log.error('database fail', :x($_)); # [23:35:44:5432][user:717]: database fail Exception X::AdHoc "database not found" <trace> 
  }}
}

sub enter(User $user) {
  $server-log.mdc-put('user-id', $user.id);
  $server-log.info('connected');     # [23:35:43:1245][user:717]: connected

  database-read();

  $server-log.info('disconnected');  # [23:35:44:9850][user:717]: disconnected
  $server-log.mdc-remove('user-id'); # it is not necessary to remove 'user-id' value from MDC 
}
```

The same configuration you can write in configuration file:

```json
{
  "writers": [{ "type": "std", "name": "logfile", "pattern": "[%date{$hh:$mm:$ss:$mss}][user:%mdc{user-id}]: %msg",
    "handle": { "type": "file", "path": "logfile.log" }}],
  "filters": [{ "type": "std", "name": "logfile", "level": "info"}],
  "cliches": [{ "name": "logfile", "matcher": "server-log", "grooves": [ "logfile", "logfile" ]}]
}
```

## Filter log by its content

Lets imagine we have an application which may writes sensible content to log
file. For example, user passwords. And we want to drop such sensible logs.
In such case we can use special sub in `do-before` action of log's `filter`.

In `Perl 6`:

```perl6
unit module Main;
use LogP6 :configure;

sub drop-passwords($context) is export {...}

cliche(:name<sensible>, :matcher<log>, grooves => (
  writer(:pattern('%msg'), :handle('logfile.log'.IO.open)),
  filter(:level($info), before-check => (&drop-passwords))
));

sub drop-passwords($context) {
  return False if $context.msg ~~ / password /;
  # If you want remove password from the log entry instead of drop it
  # you can remove the password from the message and store it in the context
  # like:
  # $context.msg-set(remove-password($context.msg));
  True;
}

sub connect(User $user) {
  get-logger('log').info('user with name %s and password %s connected', $user.id, $user.passwd);
}
```

The same configuration you can write in configuration file:

```json
{
  "writers": [{ "type": "std", "name": "writer", "pattern": "%msg",
    "handle": { "type": "file", "path": "logfile.log" }}],
  "filters": [{ "type": "std", "name": "pass-filter", "level": "info",
    "before-check": [{ "require": "Main", "fqn-method": "Main::EXPORT::DEFAULT::&drop-passwords" }]}],
  "cliches": [{ "name": "logfile", "matcher": "server-log", "grooves": [ "writer", "pass-filter" ]}]
}
```

## Write one log in several outputs

Lets imagine we have an application which works with several types of databases.
For example, Oracle and SQLite. We want to log of work with the databases. But
we want store Oracle related logs in `oracle.log` and `database.log`
files, but store SQLite related log only in `database.log`. In such case we
need one simple logger for SQLite related logs and another one (with two
grooves) for Oracle related logs.

In `Perl 6`:

```perl6
use LogP6 :configure;

set-default-pattern('%msg');
writer(:name<database>, :handle('database.log'.IO.open));
writer(:name<oracle>,   :handle(  'oracle.log'.IO.open));
filter(:name<filter>, :level($info));
cliche(:name<oracle>, :matcher<oracle>, grooves => ('database', 'filter', 'oracle', 'filter'));
cliche(:name<sqlite>, :matcher<sqlite>, grooves => ('database', 'filter'));

sub oracle-db-fetch() {
  get-logger('oracle').info('fetch data');
  # fetch
}

sub sqlite-db-fetch() {
  get-logger('sqlite').info('fetch data');
  # fetch
}
```

The same configuration you can write in configuration file:

```json
{
  "default-pattern": "%msg",
  "writers": [
    { "name": "database", "type": "std", "handle": { "type": "file", "path": "database.log"}},
    { "name": "oracle",   "type": "std", "handle": { "type": "file", "path": "oracle.log"  }}
  ],
  "filters": [{ "name": "filter", "type": "std", "level": "info" }],
  "cliches": [
    { "name": "oracle", "matcher": "oracle", "grooves": [ "database", "filter", "oracle", "filter" ]},
    { "name": "sqlite", "matcher": "sqlite", "grooves": [ "database", "filter" ]}
  ]
}
```

# BEST PRACTICE

Try to use good traits for your loggers. If you use loggers in your library then
probably using one prefix in all your traits is the best option. It allows users
of your library manage your loggers easily.

Try to choice logger trait according logger semantic or location. For example,
you can use `$?CLASS.^name` as logger trait in any your classes or traits like
`database`, `user management` or so.

If you use logger within a class then make the logger be a class field like
`has $!log = get-logger('$?CLASS.^name');` If you use logger withing a
subroutines logic then make a special sub for retrieve logger like
`sub log() { state $log = get-logger('trait'); }`. Then use it like
`log.info('msg');` It prevents any side effects caused by precompilation.

# ROADMAP

- Make IO::Handle for write log in databases;
- Make IO::Handle rollover support - change log file after some period of time
or after file size limit are reached;
- Add Writer for asynchronous writing;
- Add a `Cro::Transform` for using `LogP6` in `cro` applications.

# AUTHOR

Mikhail Khorkov <atroxaper@cpan.org>

Source can be located at: https://github.com/atroxaper/p6-LogP6. Comments and Pull Requests
are welcome.

# COPYRIGHT AND LICENSE

Copyright 2019 Mikhail Khorkov

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.