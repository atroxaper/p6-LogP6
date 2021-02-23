[![Build Status](https://github.com/atroxaper/p6-LogP6/workflows/Ubuntu/badge.svg)](https://github.com/atroxaper/p6-LogP6/actions/workflows/ubuntu.yml)
[![Build Status](https://github.com/atroxaper/p6-LogP6/workflows/Windows/badge.svg)](https://github.com/atroxaper/p6-LogP6/actions/workflows/windows.yml)

# NAME

`LogP6` is a fully customizable and fast logging library inspired by the idea of separating
logging and its configuration. You can use it not only in apps but even in your libraries.

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
		- [Async writing](#async-writing)
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
	- [Use an external library that uses LogP6](#use-an-external-library-that-uses-logp6)
	- [Change console application verbosity level](#change-console-application-verbosity-level)
	- [Conditional log calls](#conditional-log-calls)
	- [Associate logs with concrete user](#associate-logs-with-concrete-user)
	- [Filter log by its content](#filter-log-by-its-content)
	- [Write one log in several outputs](#write-one-log-in-several-outputs)
	- [Write custom writer handle for your need](#write-custom-writer-handle-for-your-need)
- [BEST PRACTICE](#best-practice)
- [SEE OLSO](#seeolso)
- [ROADMAP](#roadmap)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# SYNOPSIS

A logger system has to be as transparent as possible. At the same time, it has to be fully
customizable. It has to provide a possibility to change logging logic without changing any
line of code. It is amazing if you can use logger system during developing a library and its
user do not feel discomfort of it. `LogP6` logger library is all about that.

# DESCRIPTION

## Features

1. Possibility to change logger configuration and its behavior without touching the code;
2. Configuring from the code and/or configuration files;
3. Possibility to use any IO::Handler, even for async or database work;
4. Possibility to use multiple loggers in one app;
5. Possibility to use multiply IO::Handler's in one logger;
6. Flexible filter system;
7. Stack and Map entities associated with each thread and possibility to use values from
it in the logger;
8. Pretty fast work. Using pre-calculation as much as possible -
logger layout pattern is parsed only once, reuse current DateTime objects and so on; 
9. Possibility to use logger while development (dynamically change logger settings in runtime),
and during production work (maximum fast, without any lock, excepts possible IO::Handle
implementation's).

## Concepts

- `writer` - an object which knows how and where logs must be written. In a simple case -
which file and string format pattern will be used;
- `filter` - an object which knows which logs must be written. In simple case - logs with
which levels are allowed to pass to the `writer`;
- `cliche` - template for creating `Logger`. Contains writers, filters, and other configurations
for future Loggers;
- `logger` - instance created using configuration from the `cliche`. Just Logger with standard
functionality like `info()` method;
- `logger trait` - string value describes the semantic purpose of concrete Logger. For example,
the name of the class where the logger is used or the type of logged information (for example,
'internal-audit-subsystem'). `LogP6` uses `trait` to create the new or get already created logger;
- `cliche's matcher` - unique field of the cliche. The field may be a literal string or regex.
If the logger `trait` satisfies the `matcher` then the cliche will be used for creating the
logger with the trait;
- `context` - associated with each Thread object, which contains information for logging like
your final log message, the exception you specified, log level, current date, thread name, and
so on. Context can be used for storing some specific information you and `LogP6` library need
while logging.

## Example

Using logger:

```perl6
use LogP6;                     				# use library in general mode

my \log = get-logger('audit'); 				# create or get logger with 'audit' trait
log.info('property ', 'foo', ' setted as ', 5);   # log string with concatenation
log.infof('property %s setted as %d', 'foo', 5);  # log sprintf like style
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

LogP6 library adds an object associated with each Thread - `Logger Context` or just `context`.
You can work with the context directly in the `filter` subsystem or in custom `writer`
implementations. Also, `logger` has methods for working with `NDC` and `MDC` (see below in
[Logger](#logger)). For more information, please look at the methods' declarators in
`LogP6::Context`.

## Writer

`Writer` is responsible for writing all corresponding data to corresponding output in some format.
It has only one method: 

- `write($context){...}` - this method has to take all necessary data from the specified `context`
and use it for writing. Note: the specified context will change its data after the method call.
Do not cache the context itself (for example, for asynchronous writing) but only its data.

## Filter

`Filter` is responsible for deciding to allow the corresponding `writer` to write a log or not.
It has three methods:

- `do-before($context){...}` - some code which decides allow the log to be pass to the writer
or not. If it returns True then the log will be pass to the writer. Otherwise, the log will be
discarded.
- `reactive-level(){}` - in most cases filtering can be done only by log level. This method
returns a log level, which allows logger to call `do-before` method. If the filtering log's level
importance is less then returned reactive level, then the log will be discarded without calling
`do-before` method.
- `do-after($context){}` - any code which has to be executed after the writer work in case when
`do-before` method returns True.

## Nested Diagnostic Context (NDC) and Mapped Diagnostic Context (MDC)

There are cases when we want to trace some information through a group of log messages, but not
only in one message, for example, user id, http session number, or so. In such cases, we have to
store the information somewhere, pass it through logic subs and methods, and pass to log methods
over and over again. Since the log system has to be separated from the main program logic, then we
need a special place to store the information. That place is a `Nested Diagnostic Context`
(`NDC`) - a stack structure and a `Mapped Diagnostic Context` (`MDC`) - a map structure. You can
push/pop values in `NDC` and put/remove values in `MDC`. The standard writer has special
placeholders for message pattern (see below in [Pattern](#pattern)) for put all values from `NDC`
or some kay associated value from `MDC` to the final log message string.

## Logger

A logger is an immutable object containing zero to several pairs of  `writer` and `filter`
(`grooves`). For each time you want to log some message (with or without arguments), the logger
compiles message+arguments in one message string, updates the `context`, and goes through
`grooves` - call filter's methods and, if it passes, then ask a writer to write the message. The
writer takes all necessary information such as message, log level, NDC/MDC values, current
date-time, and so from the context.

Logger has the following methods:

- `trait()` - returns logger trait;
- `ndc-push($obj)`, `ndc-pop()`, `ndc-clean()` - work with `NDC`;
- `mdc-put($key, $obj)`, `mdc-remove($key)`, `mdc-clean()` -  work with `MDC`;
- `dc-copy()`, `dc-restore($dc-copy)` - make copy of `NDC` and `MDC` and restore
them from copy. The methods are useful when you want to share NDC and MDC values
across multiple threads.
- `trace(*@args, :$x)`, `debug(*@args, :$x)`, `info(*@args, :$x)`,
`warn(*@args, :$x)`, `error(*@args, :$x)`, `level($level, *@args, :$x)` -
logging the arguments with specified importance log level. `:$x` is an optional
exception argument. `@args` - data for logging. Elements of the array will be
concatenated with empty string;
- `tracef(*@args, :$x)`, `debugf(*@args, :$x)`, `infof(*@args, :$x)`,
`warnf(*@args, :$x)`, `errorf(*@args, :$x)`, `levelf($level, *@args, :$x)` -
logging the arguments with specified importance log level. `:$x` is an optional
exception argument. `@args` - data for logging. The first element is used as
`sprintf` format and the rest element as `sprintf` args;
- `trace-on()`, `debug-on()`, `info-on()`, `warn-on()`, `error-on()`,
`level-on($level)` - help methods to use as condition. The method will return
`Any` in case the specified log level if forbidden now and will return special
object with `log(*@args, :$x)` and `logf(*@args, :$x)` methods which can be used
for log with asked log level (see [example](#conditional-log-calls)).

## Logger Wrapper

It is a system to wrap (or decorate) logger object into another and add additional logic.
You can describe `logger wrapper factory`, which will wrap any created `logger`.

### Synchronisation of configuration and Logger instance

An example of logger wrapper usage is synchronization a logger configuration and logger instance.
It may be useful in the case of development or debug session to change logger configuration
dynamically.

Since a logger object is immutable and cannot know about configuration changes it produced,
we need a logic that checks if the user updated the corresponding configuration and updates
the logger instance.

You can specify any wrapper for logger synchronization. There is a helper class
`LogP6::Wrapper::SyncAbstract` to create your synchronization wrapper.

For now, there are only two synchronization wrappers:

- `LogP6::Wrapper::SyncTime::Wrapper` - checks the new configuration change each `X` seconds;
- `LogP6::Wrapper::SyncEach::Wrapper` - checks the new configuration change each time you use
the logger.

# CONFIGURATION

For working with the `LogP6` library, you need to `use LogP6;` module. Without any tags,
it provides only the `get-logger($trait)` sub for retrieving a logger. `:configure` tag
provides factory subroutines for configuring loggers from the code. Another option to configure
logger is by using a configuration file.

## Logger retrieve

To retrieve a logger, you need to use `LogP6` module and call the `get-logger($trait)`
sub with the logger trait you need. Example:

```perl6
use LogP6;

my $log = get-logger('main');
# using $log ...
```

If you did not configure a `Cliche` for a specified logger trait ('main' in the example),
the default logger would be returned (see  [Default logger](#default-logger)). In other cases,
the logger created by the cliche with matcher the trait satisfy will be returned.

## Factory subroutines

`LogP6` provides subroutines for configure loggers from the code dynamically. To get access to
them, you need to `use LogP6` with `:configure` tag. There are subroutines for configuring
`filters`, `writers`, `cliches`, and any default values like `writer pattern`, `logger wrapper`,
or so. Concrete subroutines will be described in the corresponding sections below. There is a
`get-logger-pure($trait)` sub to retrieve pure logger without any wrappers. Also, five variables
for five `LogP6::Level` enum values are exported as `$trace`, `$debug`, `$info`, `$warn` and
`$error`. Example:

```perl6
use LogP6 :configure;

set-default-wrapper(LogP6::Wrapper::SyncTime::Wrapper.new(:60seconds)); # set default wrapper
set-default-level($debug);    # set default logger level as debug
my $log = get-logger('main'); # get wrapped logger
$log.debug('msg');
my $pure-log = get-logger-pure('main'); # this logger will not synchronize its configuration
```

## Configuration file

A better alternative (especially for production using) of configuration by factory subroutines
is a configuration file. You can specify a path to it through `LOG_P6_JSON` system environment
variable. In case the variable is empty, then standard path `./log-p6.json` will be used
(if it exists). Or you can initialize `LogP6` library using `init-from-file($config-path)` factory
subroutine.

The configuration file is a `json` formatted file. Example:

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
The concrete format for concrete objects will be described in the corresponding sections below.

Some objects like `writers`, `wrappers` or so have a `type` filed. Each object has its own list
of available types. There is a type that can be used in any object - `custom`. It uses to describe
the factory method or class which will be used to produce the object. It requires additional
fields:
- `require` - the name of the module with factory method or class;
- `fqn-method` or `fqn-class` - the fully qualified name of method or class in `require` module;
- `args` - list of named arguments which will be passed to `fqn-method()` or `fqn-class.new()`;
- `positional` - list of positional arguments which will be passed to `fqn-method()` or `fqn-class.new()`.

For example, creating IO::Handle by `create-handle` subroutine in `MyModule` with arguments
`:path<out.txt>, :trait<rw>`:

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

`WriterConf` is a configuration object which contains all necessary information and algorithm
for creating a concrete `writer` instance. For more information, please look at the methods'
declarators in `LogP6::WriterConf`.
	
### Standard WriterConf

Standard `WriterConf` (`LogP6::WriterConf::Std`) makes a writer that writes log message to
abstract `IO::Handle`. It has a `pattern` - string with special placeholders for values like `ndc`,
current `Thread` name, log message, etc. `Writer` will put all necessary values into `pattern` and
write it to handle. Also, standard `WriterConf` has boolean `auto-exceptions` property - if it is
`True`, then the placeholder for exception will be concatenated to the `pattern` automatically.
Form of the exception placeholder can be configured separately (see [Defaults](#defaults) and
[Cliche](#cliche)).

### Pattern

Pattern placeholders start with `%` symbol following the placeholder name. If placeholder has
arguments, they can be passed in curly brackets following placeholder name.
 
The pattern can have the following placeholders:

- `%trait`, `%trait{short=[package-delimeter]number}`, `%trait{sprintf=pattern}` - for the name of
the logger trait. Additionally, you can specify one of two options of trait representation.
`sprintf` option is useful for traits like `database`, `audit`, or so when you want to represent
all traits with the same length. For example, `[%trait{sprintf=%s7}]` can be converted into
`[ audit]`. `short` option is useful for traits like `Module::Packge1::Package2::Class`. You can
specify package delimiter (instead of `::`) and how many packages will be displayed. For example,
`%trait{short=[.]1` can be converted into `Class`, `%trait{short=[.]-1` - into
`Packge1.Package2.Class` and `%trait{short=[.]2.4` - into `Modu.Pack.Package2.Class`. If `number`
is a positive integer, then only `number` right elements will be displayed. If `number` is a
negative integer, then `|number|` left elements will be deleted. If `number` is real, then left
elements will be cut to fractional symbols;
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
- `%level{WARN=W DEBUG=D ERROR=E TRACE=T INFO=I length=2}` - log importance level. By default,
the logger will use the level name in upper case, but you can specify synonyms for all or part
of them in curly brackets in format `<LEVEL_NAME>=<sysnonym>`. You can specify a fixed length
of the log level name. Default length is 0 - write level as is. For example
`'[%level{WARN=hmm ERROR=alarm length=5}]'` can be converted into `'[hmm ]'`, `'[alarm]'`,
`'[INFO ]'`, `'[DEBUG]'`;
- `%color{TRACE=yellow DEBUG=green INFO=blue WARN=magenta ERROR=red}` - colorize log string after
that placeholder. You can specify a color for any log level. The level you not specified color will
use its default color (as in the example above). For example, `%color{ERROR=green}` means
`%color{TRACE=yellow DEBUG=green INFO=blue WARN=magenta ERROR=green}`. You can use `yellow`,
`green`, `blue`, `magenta`, `green` color names or color code (more
[information](https://misc.flogisoft.com/bash/tip_colors_and_formatting). For example
`%color{TRACE=35 DEBUG=30;48;5;82 INFO=green}`. You can use `%color` placeholder several times;
- `%color{reset}` or `%creset` - reset log string colorizing after that
placeholder;
- `%date{$yyyy-$yy-$MM-$MMM-$dd $hh:$mm:$ss:$mss $z}` - current date and time.
String in curly brackets is used as
subpattern.
	- `$yyyy`, `$yy` - year in 4 and 2 digits format;
	- `$MM`, `$MMM` - month in 2 digits and short name format;
	- `$dd` - day in 2 digits format;
	- `$hh`, `$mm`, `$ss`, `$mss` - hours, minutes, seconds and milliseconds
	- `$z` - timezone
- `%framefile` - for log caller frame file name. The same as `callframe().file`
in log call block;
- `%frameline` - for log caller frame file line. The same as `callframe().line`
at the same log call line;
- `%framename` - for log caller frame code name. The same as
`callframe().code.name` in log call block;

Note that using `%framefile`, `%frameline` or `%framename` in the pattern will
slow your logging because it requires several `callframe()` calls on each
resultative log call;

### Async writing

`LogP6` provides writer and handle implementation for asynchronous writing.

You can use `LogP6::Handle::Async.new(IO::Handle :$delegate!, Scheduler :$scheduler = $*SCHEDULER)`
as a handle which will schedule `WRITE` method call of `delegate` handle.

If it is not enough to wrap a handle, then you can wrap the whole writer. Use
`LogP6::WriterConf::Async.new(LogP6::WriterConf :$delegate!, Scheduler :$scheduler = $*SCHEDULER), :$name, Bool :$need-callframe)`
as writer configuration of another configuration. The final writer will schedule the `write` method
call of `delegate` created writer with a copy of the current `logger context`. If you miss a
`:name` parameter, then `delegate`'s name will be used. Pass boolean parameter `need-callframe` if
you plan to use callframe information in the wrapped writer. Note that using callframe will slow
your logging because it requires several `callframe()` calls on each resultative log call.

### Writer factory subroutines

`LogP6` module has the following subs for manage writers configurations:

- `get-writer(Str:D $name --> LogP6::WriterConf)` - gets writer with specified name;
- `writer(:$name, :$pattern, :$handle, :$auto-exceptions, :create, :update, :replace --> LogP6::WriterConf)` -
create, update, or replace standard `WriterConf` with a specified name. If you want to `:update`
only concrete fields in an already created configuration, then the rest fields will not be changed.
In the case of `:replace`, the new configuration will be created and replaced the old one. You can
create configuration without a name - then the configuration will not be stored but only returned
to you. The method returns the old writer configuration (`:update`, `:replace`) and the new one
(`:create`);
- `writer(LogP6::WriterConf:D $writer-conf, :create, :replace --> LogP6::WriterConf)` - save or
replace any implementation of `WriterConf`. The configuration name will be retrieved from the
`$writer-conf`. The method returns the old writer configuration (`:replace`) and the new one
(`:create`);
- `writer(:$name, :$remove --> LogP6::WriterConf)` - remove and return a configuration with
specified name.

### Writer configuration file

In the configuration file, writer configurations have to be listed in `writers` array. Only `std`
(for standard configuration) and `custom` types are supported.

In the case of standard configuration, all fields are optional excepts `name`. The handle can be:

- `file` type for output into a file. You can specify `path`,`append` (`True` by default), and
`out-buffer` arguments;
- `std` type for output into `$*OUT` or `$*ERR`. You can specify `path` as `out` or `err`.
- `custom` type.

In the case of the `custom` writer type, the result writer configuration has to returns not empty
name.

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

`Filter` creates by `FilterConf` - a configuration object which contains all necessary information
and algorithm for creating a concrete `filter` instance. For more information, please look at the
methods' declarators in `LogP6::FilterConf`.

### Standard FilterConf

Standard `FilterConf` (`LogP6::FilterConf::Std`) has array for `do-before` subs and array for
`do-after` subs. `Filter` made by standard `FilterConf` calls each `do-before` sub and stop at the
first `False` returned value. If all `do-before` subs returned `True`, then the filter's
`do-before` method returns `True`. The `do-after` works in the same way. Also, there is a
`first-level-check` property. If it is set to `True`, then the sub for checking log level will be
added automatically as the first element in `do-before` array; if the property set to `False` then
the sub will be added automatically as the last element in `do-before` array.

### Filter factory subroutines

`LogP6` module has the following subs for manage filters configurations:

- `get-filter(Str:D $name --> LogP6::FilterConf)` - gets filter with specified name
- `filter(:$name, :$level, :$first-level-check, List :$before-check, List :$after-check, :create, :update, :replace --> LogP6::FilterConf)` -
create, update, or replace standard `FilterConf` with a specified name. If you want to `:update`
only concrete fields in already created configuration then the rest fields will not be changed.
In the case of `:replace`, the new configuration will be created and replaced the old one. You can
create a configuration without a name - then the configuration will not be stored but only
returned to you. The method returns the old filter configuration (`:update`, `:replace`) and the
new one (`:create`);
- `level($level --> LogP6::FilterConf:D)` - the short form for `filter(:level($level), :create)`;
- `filter(LogP6::FilterConf:D $filter-conf, :create, :replace)` - save or replace any
implementation of `FilterConf`. The configuration name will be retrieved from the `$filter-conf`.
The method returns the old filter configuration (`:replace`) and the new one (`:create`);
- `filter(:$name, :$remove)` - remove and return a configuration with specified name.

### Filter configuration file

In the configuration file, filter configurations have to be listed in the `filters` array.
Only `std` (for standard configuration) and `custom` types are supported.

In the case of standard configuration, all fields are optional excepts `name`. `before-check`
and `after-check` are arrays with `custom` typed elements.

In the case of the `custom` filter type, the result filter configuration has to returns not
empty name.

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

Standard filters and writers have fields and options which affect their work. Some of them you
can specify in factory subroutines or configuration file fields. If such arguments are omitted,
then the default values of it will be used. Other fields and options cannot be setter this way.
For example, the pattern for an exception that will be concatenated to the main pattern in the
standard writer when `auto-exceptions` sets to `True`
(see [Standard WriterConf](#standard-writerconf)). Such properties have default values too. All
the defaults can be set through factory subroutines or fields in the configuration file.

Configuring default values is useful in case you what to avoid many boilerplate configurations.

### Defaults factory subroutines

There are the following factory subs for set defaults values:

- `set-default-pattern(Str:D $pattern)` - set default pattern for the standard `WriterConf`.
Default value is `'[%date{$hh:$mm:$ss}][%level] %msg'`;
- `set-default-auto-exceptions(Bool:D $auto-exceptions)` - set default `auto-exceptions` property
value for the standard `WriterConf`. Default value is `True`;
- `set-default-handle(IO::Handle:D $handle)` - set default handle for the standard `WriterConf`.
Default value is `$*OUT`;
- `set-default-x-pattern(Str:D $x-pattern)` - set pattern for exception that will be concatenated
to the main pattern in standard `WriterConf` in case `auto-exceptions` sets to `True`
(see [Standard WriterConf](#standard-writerconf)). Default value is
`'%x{ Exception $name: $msg' ~ "\n" ~ '$trace}'`
- `set-default-level(LogP6::Level:D $level)` - set default level for the standard `WriterConf`.
Default value is `LogP6::Level::error`;
- `set-default-first-level-check(Bool:D $first-level-check)` - set default value
of `first-level-check` property of the standard `FilterConf`
(see [Standard FilterConf](#standard-filterconf)). Default value is `True`;
- `set-default-wrapper(LogP6::Wrapper $wrapper)` - set wrapper for loggers
(see [Logger Wrapper](#logger-wrapper)). Default value is
`LogP6::Wrapper::Transparent::Wrapper.new`.

### Defaults configuration file

You can configure default values in the configuration file through the following json fields of a
root object:

- `"default-pattern": <string>` - for default pattern for writers with `std` type;
- `"default-auto-exceptions": <boolean>` - for default `auto-exceptions` field value for writers
with `std` type;
- `"default-handle": <handle>` - for default handle for writers with `std` type;
- `"default-x-pattern": <string>` - for default exceptions pattern for writers with `std` type;
- `"default-level": <level-name>` - for default level for filters with `std` type;
- `"default-first-level-check": <boolean>` - for `first-level-check` value for filters with `std`
type;
- `"default-wrapper": <wrapper>` - for wrapper for loggers.

`Wrapper` can be:

- `time` type for `LogP6::Wrapper::SyncTime::Wrapper`. It takes obligatory `"seconds": <num>` and
optional `"config-path": <string>` addition fields;
- `each` type for `LogP6::Wrapper::EachTime::Wrapper`. It takes optional `"config-path": <string>`
addition field;
- `transparent` type for `LogP6::Wrapper::Transparent::Wrapper`;
- `custom` type.

## Cliche

`Cliche` is a template for creating Logger. Each `cliche` has `cliche's matcher` - literal or
regex field. When you what to get logger for some `logger trait`, then the logger system tries
to find a `cliche` with `matcher` the `trait` satisfies (by smartmatch). If there is more than
one such cliche, then the most recent created will be picked. The picked `cliche`'s content will
be used for making the new logger.

Cliche contains writers and filters configurations pairs called `grooves` and own `defaults` values
which overrides global `defaults` values (see [Defaults](#defaults)). You can use the same writer
and/or filter in several `grooves`. If the `grooves` list is empty or missed, the created logger will
drop all logs you pass to it;

### Cliche factory subroutines

`LogP6` module has the following subs for manage cliches configurations:

- `cliche(:$name!, :$matcher!, Positional :$grooves, :$wrapper, :$default-pattern, :$default-auto-exceptions, :$default-handle, :$default-x-pattern, :$default-level, :$default-first-level-check, :create, :$replace)` -
create or replace cliche with specified name and matcher. All passed `defaults` overrides globals
`defaults` in within the cliche. `$grooves` is a `Positional` variable with alternating listed
`writers` and `filters`. `$grooves` will be flatted before analysis - you can pass into it a list
of two elements lists or any structure you want. Elements of `$grooves` can be either name of
already stored writers and filters, already stored writers and filters with names, or writers and
filters without names. In the last case, the writer or filter will be stored with a generated UUID
name automatically. The method returns the old cliche (`:replace`) and the new one (`:create`);
- `cliche(LogP6::Cliche:D $cliche, :create, :replace)` - save or replace cliche;
- `cliche(:$name!, :remove)` - remove and return a cliche with specified name.

### Cliche configuration file

In the configuration file, cliches have to be listed in the `cliches` array. It has the following
fields:

- `"name": <string>` - obligatory name of cliche;
- `"matcher": <string>` - cliche matcher. If the matcher value starts and ends with `/` symbol,
then the matcher is interpreted as regex; in another case, it is a literal;
- `"grooves": [<writer1-name>, <filter1-name>, <writer2-name>, <filter2-name>, ... ]` - grooves,
list of writers' and filters' names;
- defaults - the same fields with the same possible values as described in
[Defaults configuration file](#defaults-configuration-file) excepts `default-wrapper` - you need
to use the `wrapper` field name.

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

In any way you configured your cliches by the factory routines or configuration file or did not
use non of them, the `default cliche` will be in the logger library. Default cliche corresponds
to the following configuration:
`cliche(:name(''), :matcher(/.*/), grooves => (writer(:name('')), filter(:name(''))))`. In other
words, default cliche has an empty string name, matches any trait, has only one groove with empty
(uses all defaults) writer with an empty string name and with empty (uses all defaults) filter with
an empty string name. It means, by default, you do not need to configure anything at all. But you
can change the default cliche or default writer and filter by factory subroutines or in the
configuration file. Note that if the `LogP6` library does not find cliche with matcher logger trait
satisfies, then an exception will be thrown.

## Change configuration

Sometimes you may need to change logger configuration in runtime execution. It can be simply done
by factory subroutines. After calling any factory subroutine, all loggers for already used
`logger traits` will be recreated, and you can get it by `get-logger($trait)` sub. If you already
got logger, use synchronization wrapper, then the wrapper will sync the logger himself correspond
to its algorithm.

Another way of change configuration is by using configuration file modification. Changes in the
configuration file will be detected only if you are already using any of the synchronization
wrappers (in `defaults` or one of `cliches`). After any change detection, all already configured
configuration will be dropped and created new from the file.

# EXAMPLES

Lets explore a few general use cases:

## Use an external library that uses LogP6

`LogP6` can be used during library development, and a user of the library wants entirely turn off
any logs from the library. Let's imagine that all library loggers' traits start with `LIBNAME`
letters. In this case, we can create a `cliche` with corresponding `matcher` and empty `grooves` -
all library logs will be dropped.

In `Raku`:

```perl6
use LogP6 :configure;

cliche(:name('turn off LIBNAME'), :matcher(/^LIBNAME .*/), :wrapper(LogP6::Wrapper::Transparent::Wrapper.new));
```

Or in the configuration file:

```json
{ "cliches": [{"name": "turn off LIBNAME", "matcher": "/^LIBNAME .*/", "wrapper": {"type": "transparent"}}] }
```

We use wrapper without synchronization (transparent) because we do not plan to change the library
loggers' configuration.

## Change console application verbosity level

Let's imagine we are writing a console application, and we want to add the flag `--verbose` for
getting a more detailed output. Lets using a particular logger for application console output
instead of using simple `say` and change filter level according to the user's choice:

In `Raku`:

```perl6
use LogP6 :configure;

cliche(:name<output>, :matcher<say>, grooves => (
  writer(:pattern('%msg'), :handle($*OUT)),
  filter(:name<verbosity>, :level($info))
));

sub MAIN(Bool :$verbose) {
  filter(:name<verbosity>, :level($debug), :update) if $verbose;
  my $say = get-logger('say');
  $say.info('Greetings');
  $say.debugf('You set verbose flag to %s value', $verbose);
}
```

In that case, we do not need to use the configuration file. But if you want, then you can remove
the line with `cliche` creation and add the following configuration file:

```json
{
  "writers": [{ "type": "std", "name": "say", "pattern": "%msg", "handle": { "type": "std", "path": "out" }}],
  "filters": [{ "type": "std", "name": "verbosity", "level": "info"}],
  "cliches": [{ "name": "output", "matcher": "say", "grooves": [ "say", "verbosity" ]}]
}
```

## Conditional log calls

Sometimes you may need to log information that required additional calculation. It is useful
to know whether the log will be written or not before the calculation. Logger's `-on` methods
were created especially for that. It will return a particular object (or Any) with `log` and
`logf` methods you can use to log with the corresponding log level. Please look at the example
below:

```perl6
use LogP6 :configure;

# set logger allowed level as INFO
filter(:name(''), :level($info), :update);
my $log = get-logger('condition');
my %map;
my $str;
# ...

# to-json will not be called here, because .debug-on returned Any for now
.log(to-json(%map, :pretty, :sorted-keys)) with $log.debug-on;

# from-json will be called here, because .warn-on returned a little logger
# log will be with WARN level
.log(from-json($str)<key>) with $log.warn-on;

with $log.trace-on {
  # this block will not be executed for now
  my $user-id = retrive-the-first-user-id-from-db();
  # use logf method to use sprintf-style logs
  .logf('the first user id in the database is %d', $user-id);
}

# Be careful with '.?' operator. Sins it is not an operator but syntax-sugar
# to-json will be called in any case, but log will not be written for now.
$log.debug-on.?log(to-json(%map, :pretty, :sorted-keys));
```

## Associate logs with concrete user

Let's imagine we write a server application. Many users can connect to the server simultaneously
and do some action, which produces log messages in a log file. If some exception will be caught
and log, we want to reconstruct the user's execution flow to understand what went wrong. But
needful records in the log file will be alongside logs from other users' actions. In such cases,
we need to associate each log entry with some user id. Then we can grep the log file for the user
id. For that, use `MDC`.

In `Raku`:

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

The same configuration you can write in the configuration file:

```json
{
  "writers": [{ "type": "std", "name": "logfile", "pattern": "[%date{$hh:$mm:$ss:$mss}][user:%mdc{user-id}]: %msg",
    "handle": { "type": "file", "path": "logfile.log" }}],
  "filters": [{ "type": "std", "name": "logfile", "level": "info"}],
  "cliches": [{ "name": "logfile", "matcher": "server-log", "grooves": [ "logfile", "logfile" ]}]
}
```

## Filter log by its content

Imagine we have an application that may write sensible content to log files, for example,
user passwords. And we want to drop such sensible logs. We can use a particular sub in `do-before`
action of log's `filter`.

In `Raku`:

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
  # If you want to remove a password from the log entry instead of dropping it,
  # you can remove the password from the message and store it in the context like:
  #
  # $context.msg-set(remove-password($context.msg));
  True;
}

sub connect(User $user) {
  get-logger('log').infof('user with name %s and password %s connected', $user.id, $user.passwd);
}
```

The same configuration you can write in the configuration file:

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

Let's imagine we have an application that works with several types of a database -- for example,
Oracle and SQLite. We want to log work with the databases. But we want to store Oracle related
logs in `oracle.log` and `database.log` files, and SQLite related records only in `database.log`.
In this case, we need a straightforward logger for SQLite related logs and another one (with two
grooves) for Oracle associated logs.

In `Raku`:

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

The same configuration you can write in the configuration file:

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

## Write logs in journald

Let's imagine you want to store logs in journald service. You can use `LogP6::Writer::Journald`
module for that. For more information, please look at the writer module README.
Example of configuration:

In `Raku`:

```perl6
use LogP6 :configure;

writer(LogP6::WriterConf::Journald.new(
  # name, pattern and auto-exceptions as in standard writer
  :name<to-journald>, :pattern('%msg'), :auto-exeptions
  # which additional information must be written
  :use-priority, # write 'PRIORITY=' field to journald automatically
  :use-mdc       # write all MDC contend as field to journald in 'key=value' format
));
```

The same configuration you can write in the configuration file:

```json
{"writers": [{
  "type": "custom",
  "require": "LogP6::WriterConf::Journald",
  "fqn-class": "LogP6::WriterConf::Journald",
  "args": {
    "name": "to-journald",
    "pattern": "%msg",
    "auto-exceptions": true,
    "use-priority": true,
    "use-mdc": true
  }
}]}
```

## Write custom writer handle for your need

Sometimes you may need to write log to some exotic place. In this case you will need to implement
your own `Writer` and its `WriterConf`. In simple cases, it would be enough to implement your own
`IO::Handle` for the standard writer. For example, there is no de-facto must-use library for
working with databases yet. That is why there is no particular writer for it in `LogP6`. But let's
try to write it now:

Imagine we decided to use `SQLite` database and `DB::SQLite` library. We can ask the standard
writer to prepare SQL insert expression for us. Therefore we can only write custom `IO::Handle`.
Fortunately, it is easy in `6.d` version:

```perl6
unit module MyDBHandle;
use DB;
use DB::SQLite;

class DBHandle is IO::Handle {
  has Str $.filename is required;
  has DB $!db;

  submethod TWEAK() {
    self.encoding: 'utf8';
    # open database file and create table for logging
    $!db = DB::SQLite.new(:$!filename);
    $!db.execute('create table if not exists logs (date text, level text, log text)');
  }

  method WRITE(IO::Handle:D: Blob:D \data --> Bool:D) {
    # decode Blob data and execute. we expect the valid sql dml expression in data.
    $!db.execute(data.decode());
    True;
  }

  method close() { $!db.finish } # close database

  method READ(|) { #`[do nothing] }

  method EOF { #`[do nothing] }
}
```

It is all we need. Now we can write the `LogP6` configuration. In `Raku`:

```perl6
use MyDBModule;
use LogP6 :configure;

writer(
  :name<db>,
  # pattern provides us a valid sql dml expression
  :pattern('insert into logs (date, level, log) values (\'%date\', \'%level\', \'%msg%x{ - $name $msg $trace}\')'),
  # handle with corresponding database filename
  handle => DBHandle.new(:filename<database-log.sqlite>),
  # turn off auto-exceptions because it will corrupt our sql dml expression
  :!auto-exceptions
);
cliche(:name<db>, :matcher<db>, grooves => ('db', level($trace)));

my $log-db = get-logger('db');

$log-db.info('database logging works well');
```

The same configuration you can write in the configuration file:

```json
{
  "writers": [{
    "type": "std",
    "name": "db",
    "pattern": "insert into logs (date, level, log) values ('%date', '%level', '%msg%x{ - $name $msg $trace}'",
    "handle": {
      "type": "custom",
      "require": "MyDBModule",
      "fqn-class": "MyDBModule::DBHandle",
      "args": {
        "filename": "database-log.sqlite"
      }
    },
    "auto-exceptions": false
  }],
  "filters": [{ "name": "filter", "type": "std", "level": "trace" }],
  "cliches": [{
    "name": "db",
    "matcher": "db",
    "grooves": [ "db", "filter" ]
  }]
}
```

## Rollover log files

Log files tend to grow in size. There is `IO::Handle::Rollover` module to prevent such uncontrolled
growth. For example, you decided to store only 30MB of logs separated into three files for
convenience. For that, you only need to create a custom handle with an `open` routine like that:

In `Raku`:

```perl6
use IO::Handle::Rollover;
my $handle = open("log.txt", :w, :rollover, :file-size<10M>, :3history-size);
```

The same initialization you can write in the configuration file:

```json
{
...
  "handle": {
    "type": "custom",
    "require": "IO::Handle::Rollover",
    "fqn-method": "IO::Handle::Rollover::EXPORT::DEFAULT::&open",
    "positional": [ "log.txt" ],
    "args": {
      "w": true,
      "rollover": true,
      "file-size": "10M",
      "history-size": 3
    }
  }
...
}
```

You can use the handle as any other output handles, for example, in LogP6 writers. For more
information, see the documentation for the `IO::Handle::Rollover` module.

# BEST PRACTICE

Try to use good traits for your loggers. If you use loggers in your library, then probably using
one prefix in all your traits is the best option. It allows users of your library to manage your
loggers easily.

Try to choose a logger trait according to logger semantic or location. For example, you can use
`$?CLASS.^name` as a logger trait in any of your classes or traits like `database`,
`user management`, or so.

If you use logger within a class then make the logger be a class field like
`has $!log = get-logger('$?CLASS.^name');` If you use logger withing a subroutines logic then make
a special sub for retrieve logger like `sub log() { state $log = get-logger('trait'); }`. Then use
it like `log.info('msg');` It prevents any side effects caused by precompilation.

# SEE OLSO

- [LogP6::Writer::Journald](https://modules.raku.org/dist/LogP6-Writer-Journald:cpan:ATROXAPER)
- [IO::Handle::Rollover](https://modules.raku.org/dist/IO-Handle-Rollover:cpan:ATROXAPER)

# ROADMAP

- Add a `Cro::Transform` for using `LogP6` in `cro` applications.

# AUTHOR

Mikhail Khorkov <atroxaper@cpan.org>

Source can be located at: [github](https://github.com/atroxaper/p6-LogP6). Comments and Pull Requests
are welcome.

# COPYRIGHT AND LICENSE

Copyright 2020 Mikhail Khorkov

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.
