[![Build Status](https://travis-ci.org/TODO)](https://travis-ci.org/TODO)

# NAME

LogP6 - full customisable and fast logging library inspired by idea of separate
logging and logging configuration. You can use it not only in apps but even in
your own libraries.

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
	- [Factory methods](#factory-methods)
	- [Configuration file](#configuration-file)
	- [Writer configuration](#writer-configuration)
		- [WriterConf](#writerconf)
		- [Standard WriterConf](#standard-writerconf)
		- [Pattern](#pattern)
		- [Writer factory methods](#writer-factory-methods)
		- [Writer configuration file](#writer-configuration-file)
	- [Filter configuration](#filter-configuration)
		- [FilterConf](#filterconf)
		- [Standard FilterConf](#standard-filterconf)
		- [Filter factory methods](#filter-factory-methods)
		- [Filter configuration file](#filter-configuration-file)
	- [Defaults](#defaults)
		- [Defaults factory methods](#defaults-factory-methods)
		- [Defaults configuration file](#defaults-configuration-file)
- [EXAMPLES](#examples)
- [BEST PRACTICE](#best-practice)
- [KNOWN ISSUES](#known-issues)
- [ROADMAP](#roadmap)
- [AUTHOR](#author)
- [COPYRIGHT AND LICENSE](#copyright-and-license)

# SYNOPSIS

    

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
excepts possible IO::Handle implementation's);
10. TODO stateless and immutable

## Concepts

- **Writer** - an object which know how and where logs must be written. In simple
case - which file and string format pattern will be used. 
- **Filter** - an object which know which logs must be written. In simple case -
logs with which levels are allowed to pass to the Writer.
- **Cliche** - template for creating Logger. Contains writers, filters and other
configurations for future Loggers.
- **Logger** - instance created using configuration from the Cliche. Just logger
with standard functionality like .info() method.
- **Logger trait** - string value describes semantic purpose of concrete Logger. For
example, the name of class where the logger is used or the type of logged
information ('internal-audit-subsystem'). Used for create the new or get already
created logger.
- **Cliche's matcher** - special field of the Cliche. The field may be a literal
string or regex. If the logger trait satisfies cliche's matcher then the cliche
will be used for creating the logger with the trait.
- **Context** - associated with each Thread object which contains information
for logging like final user log message, user's exception, log level user want,
current date, thread name and so on. Context can be used for storing some
specific information you (and logger system) need while logging. 

## Example

Using logger:
```perl6
use LogP6;                     				# use library in general mode
my \log = get-logger('audit'); 				# create or get logger with 'audit' trait
log.info('property ' ~ 'foo' ~ ' setted as ' ~ 5); 	# log string with concatenation
log.info('property %s setted as %d', 'foo', 5);    	# log sprintf like style
```

Configure in the code style:
```perl6
use LogP6 :configure;   # use library in configure mode
cliche(                 # create a cliche
  :name<cl>,            # obligatory unique cliche name
  :matcher<audit>,      # obligatory matcher
  grooves => (          				# optional list of writer-filter pairs (or their names)
    writer(:pattern('%level| %msg'), :handle($*ERR)),   # create anonymous (w/o name) writer configuration
    filter(:level($debug))));                           # create anonymous (w/o name) filter configuration
```

Configure in the configuration file style (same as above):
```json
{
  "writers": [{               # describe all your writer configurations
    "type": "std",
    "name": "w",              # obligatory unique writer name
    "pattern": "%level | %msg",
    "handle": { "type": "std", "path": "err" }
  }],
  "filters": [{               # describe all your filter configurations
    "type": "std",
    "name": "f",              # obligatory unique filter name
    "level": "debug"
  }],
  "cliches": [{               # describe all your cliches
    "name": "cl",             # obligatory unique cliche name
    "matcher": "audit",       # obligatory matcher
    "grooves": [ "w", "f" ]   # optional list of writer-filter configurations names pairs 
  }]
}
```

## Context

LogP6 library adds an object associated with each Thread - `Logger Context` or
just `Context`. User can work with the `Context` directly in `Filter` subsystem
or in custom `Writer` implementations. Also `Logger` has special methods
for working with `NDC` and `MDC` (see below in [Logger](#logger)). For more
information please look at methods' declarators in `LogP6::Context`.

## Writer

`Writer` is responsible to write all corresponding data to corresponding output
in some format. It has only one method: 

- `write($context){...}` - this method have to take all necessary data from the
specified `Context` and use it for writing. Note: the specified `Context` will
change its data after method call. Do not cache the context itself (for example
for asynchronous writing) but only its data.

## Filter

`Filter` is responsible to decide allow the corresponding `Writer` to write log
or not. It has three methods:

- `do-before($context){...}` - some code which decides allow log to be pass to
the writer or not. If it returns True then the log will be pass to the writer.
Otherwise the log will be discarded.
- `reactive-level(){}` - in most cases filtering can be done only by
log level. This method returns a log level which allows logger to call
`do-before` method. If filtering log's level importance is less then returned
reactive level then the log will be discarded without calling `do-before`
method.
- `do-after($context){}` - any code which have to be executed after the writer
work in case when `do-before` method returns True.

## Nested Diagnostic Context (NDC) and Mapped Diagnostic Context (MDC)

There are cases when we want to trace some information through group of log
message, but not only in one message. For example, used id, http session
number or so. In such cases we have to store the information somewhere, pass
it through logic subs and methods and pass to log methods over and over again.
Since log system have to be separated from the main logic then we need a special
place to store the information. That place is a Nested Diagnostic Context
(`NDC`) - a stack structure and a Mapped Diagnostic Context (`MDC`) - a map
structure. User can push/pop values in `NDC` and put/delete values in `MDC`.
Standard writer has special placeholders for message pattern
(see below in [Writer configuration](#writer-configuration)) for put all values from
`NDC` or some kay associated value from `MDC` to final log message string.

## Logger

The logger is an immutable object that contains from zero to several pairs of 
`writer` and `filter` (`grooves`). For each time the user want to log some
message (with or without arguments) the logger compiles message+arguments in
one `msg string`, updates the [logger context](#context) and goes through
`grooves` - call `filter`'s methods and if it pass then ask a writer to write 
`msg string`. The `writer` takes all necessary information such as `msg string`,
log level, `ndc/mdc` values, current date-time and so from the `context`.

Logger has the following methods:

- `trait(){...}` - returns logger trait;
- `ndc-push($obj){...}`, `ndc-pop(){...}`, `ndc-clean(){...}` - working with
NDC;
- `mdc-put($key, $obj){...}`, `mdc-remove($key){...}`, `mdc-clean(){...}` - 
working with MDC;
- `trace(*@args, :$x){...}`, `debug(*@args, :$x){...}`,
`info(*@args, :$x){...}`, `warn(*@args, :$x){...}`, `error(*@args, :$x){...}` -
log arguments with specified importance log level. `:$x` is an optional
exception argument. `@args` - data for logging. If the array has more then one
element then the first element is used as format for sprintf sub and the rest
element as sprintf args;

## Logger Wrapper

System to wrap (or decorate) logger object into another and add additional
logic. User can describe `logger wrapper factory` which will wrap any created
`logger`.

### Synchronisation of configuration and Logger instance

An example of usage a logger wrapper is synchronisation a logger configuration
and logger instance. It may be useful in case of development or debug session
when a user what to change logger configuration dynamically.

Since a logger object are immutable and cannot know about changes in
configuration it produced, we need a logic for checking if user updated
corresponding configuration and updating the logger instance.

User can specify any kind of wrapper for synchronization a logger. There are
helper class `LogP6::Wrapper::SyncAbstract` to create your own synchronization
wrappers.

For now there is only one synchronization wrapper -
`LogP6::Wrapper::SyncTime::Wrapper`. The wrapper check the new configuration
(in a configuration file or in code) each `X` seconds.

# CONFIGURATION

For working with `LogP6` system a user have to `use LogP6;` module. Without any
tags it provides sub for only retrieving a logger. `:configure` tag provides
factory methods for configuring loggers from the code. Another option to
configure logger is using configuration file.

## Logger retrieve

For retrieve a logger user have to use `LogP6` module and call `get-logger` sub
with logger trait he need. Example:

```perl6
use LogP6;

my $log = get-logger('main');
# using $log ...
```

If user did not configure a `Cliche`
(see [Standard configuration](#standard-configuration)) for specified logger
trait ('main' in example), the default logger will be returned. In other case
the logger created by the cliche with matcher the trait satisfy will be
returned.

## Factory methods

`LogP6` provides method for configure loggers from the code dynamically.
To get access to them you have to `use LogP6` with `:configure` tag. There are 
methods for configuring `filters`, `writers`, `cliches` and any default values
like `writer pattern`, `logger wrapper` or so. Concrete methods will be
described in corresponding sections below. Also five variables for five
`LogP6::Level` enum values are exported as `$trace`, `$debug`, `$info`, `$warn`
and `$error`. Example:

```perl6
use LogP6 :configure;

set-default-level($debug);    # set default logger level as debug
my $log = get-logger('main');
$log.debug('msg');
```

## Configuration file

Better alternative (especially for production using) or configuration by factory
methods is configuration file. You can specify path to it through `LOG_P6_JSON`
system environment variable. In case the variable is empty then standard path
`./log-p6.json` will be used. If the file will be missed then standard
configuration will be used (if it exists).

Configuration file is json like formatted file like:

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
used to produce the object. It require additional fields:
- `require` - name of module with method or class;
- `fqn-method` or `fqn-class` - full qualified name of method or class in
`require` module;
- `args` - list of named arguments which will pass to `fqn-method()` or
`fqn-class.new()`.

For example, creating IO::Handle by `create-handle` method in `MyModule` with
arguments `:path<out.txt>, :trait<rw>`:

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
and algorithm for creating a concrete `Writer` instance. For more
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
`%x{($name '$msg') Trace: $trace}` can be converted into
`(X::AdHoc 'test exception') Trace: ...`;
- `%level{WARN=W DEBUG=D ERROR=E TRACE=T INFO=I length=2}` - log importance
level. By default logger will use level name in upper case but you can
specify synonyms for all (or part) of them in curly brackets in format
`<LEVEL_NAME>=<sysnonym>`. Also you can specify a length of log level name.
Default length is 5. For example `[%level{WARN=hmm ERROR=alarm length=5}]` can
be converted into `[hmm  ]`, `[alarm]`, `[INFO ]`, `[DEBUG]`;
- `%date{$yyyy-$yy-$MM-$MMM-$dd $hh:$mm:$ss:$mss $z}` - current date and time.
String in curly brackets is used as
subpattern.
	- `$yyyy`, `$yy` - year in 4 and 2 digits format;
	- `$MM`, `$MMM` - month in 2 digits and short name format;
	- `$dd` - day in 2 digit format;
	- `$hh`, `$mm`, `$ss`, `$mss` - hours, minutes, seconds and milliseconds
	- `$z` - timezone

### Writer factory methods

`LogP6` module has the following subs for manage writers configurations:

- `get-writer(Str:D $name --> LogP6::WriterConf)` - gets writer with specified
name
- `writer(:$name, :$pattern, :$handle, :$auto-exceptions, :create, :update, :replace --> LogP6::WriterConf)` -
create, update or replace standard `WriterConf` with specified name. If you want
to `:update` only concrete fields in already created configuration then the rest
fields will not be changed. In case of `:replace` the new configuration will be
created and replaced the old one. You can create configuration without name -
then the configuration will not be stored, but only returned to you. The method
returns the old writer configuration (`:update`, `:replace`) and the new one
(`:create`);
- `writer(LogP6::WriterConf:D $writer-conf, :create, :replace --> LogP6::WriterConf)` -
create or replace any implementation of `WriterConf`. The configuration name
will be retrieved from the argument itself; The method returns the old writer
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
- `std` type for output into `$*OUT` or `$*ERR`. You can specify `path` as `out` or
`err`.
- `custom` type.

In case of `custom` writer type the result writer configuration have to returns
not empty name.

Example:

```json
{
  ...
  "writers": [
    {"type": "std", "name": "w1", "pattern": "%msg", "handle": {"type": "std", "path": "out"}},
    {"type": "std", "name": "w2", "handle": {"type": "file", "path": "log.txt", "append": false}},
    {"type": "custom", "require": "Module", "fqn-method": "Module::EXPORT::DEFAULT::&writer", "args": { "name": "w3" }
  ]
  ...
}
```

## Filter configuration

### FilterConf

`Filter` creates by `FilterConf` - a configuration object which contains all
necessary information and algorithm for creating a concrete `Filter` instance.
For more information please look at methods' declarators in `LogP6::FilterConf`.

### Standard FilterConf

Standard `FilterConf` (`LogP6::FilterConf::Std`) has array for `do-before` subs
and array for `do-after` subs. `Filter` made by standard `FilterConf` calls 
each `do-before` sub and stop at the first `False` returned value. If all all
`do-before` subs returned `True`, then the `filter`'s `do-before` method returns
`True`. The `do-after` work in the same way. Also there is `first-level-check`
property. If it set to `True` then the sub for checking log level will be added
automatically as the first element in `do-before` array; if the property set to
`False` then the sub will be added automatically as the last in `do-before`
array.

### Filter factory methods

`LogP6` module has the following subs for manage filters configurations:

- `get-filter(Str:D $name --> LogP6::FilterConf)` - gets writer with specified
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
create or replace any implementation of `FilterConf`. The configuration name
will be retrieved from the argument itself; The method returns the old filter
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
  ...
  "filters": [
    {"type": "std", "name": "f1", "level": "error", "first-level-check": false},
    {"type": "std", "name": "f2", "level": "info", "before-check": [{ "require": "MyModule", "fqn-method": "MyModule::EXPORT::DEFAULT::&before-check" }]},
    {"type": "custom", "require": "MyModule", "fqn-class": "MyModule::MyFilter", "args": { "name": "f3" }
  ]
  ...
}
```

## Defaults

Standard filters and writers has fields and options which affect their work.
Some of them you can specify in factory methods or configuration file fields.
If such arguments are omitted then the default values of it will be used.
Another fields and options cannot be setter this way. For example, pattern for
exception which will be concatenated to main pattern in standard writer when
`auto-exceptions` sets to `True`
(see [Standard WriterConf](#standard-writerconf)). Such properties have default
values too. All the defaults can be set through factory methods or filed in
configuration file.

Configuring default values are useful in case you what to avoid many boilerplate
configurations

### Defaults factory methods

There are the following factory methods for set defaults values:

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
`'%x{ Exception $name: $msg' ~ "\n" ~'$trace}'`
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
json fields of root object:

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

- `time` type for `LogP6::Wrapper::SyncTime::Wrapper`. It takes required
`"seconds": <num>` and optional `"config-path": <string>` addition fields;
- `transparent` type for `LogP6::Wrapper::Transparent::Wrapper`;
- `custom` type.

## Cliche
### Cliche factory methods
### Cliche configuration file

## Default logger

## Change configuration

configuration options priority

# EXAMPLES

# BEST PRACTICE

# KNOWN ISSUES

# ROADMAP

# AUTHOR

Mikhail Khorkov <atroxaper@cpan.org>

Source can be located at: https://github.com/TODO . Comments and Pull Requests are welcome.

# COPYRIGHT AND LICENSE

Copyright 2018 Mikhail Khorkov

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.