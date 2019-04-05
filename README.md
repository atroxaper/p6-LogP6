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

`Writer` creates by `WriterConf` - a configuration object which contains all
necessary information and algorithm for creating a concrete `Writer` instance.
(see below in [Writer configuration](#writer-configuration)).

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

`Filter` creates by `FilterConf` - a configuration object which contains all
necessary information and algorithm for creating a concrete `Filter` instance.
(see below in [Configure Filter](#configure-filter)).

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
writer and filter. For each time the user want to log some message (with or
without arguments) the logger compiles message+arguments in one `msg string`,
updates the [logger context](#context) and goes through `writer-filter` pairs -
call `filter`'s methods and if it pass then ask a writer to write `msg string`.
The `writer` takes all necessary information such as `msg string`, log level,
`ndc/mdc` values, current date-time and so from the `context`.

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

## Retrieve logger

## Factory methods....

## Configuration file....

## Writer configuration
### WriterConf
### Std
### Pattern
### Writer factory methods
### Writer configuration file

## Filter configuration
### FilterConf
### Std
### Filter factory methods
### Filter configuration file

## Cliche
### Cliche factory methods
### Cliche configuration file

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