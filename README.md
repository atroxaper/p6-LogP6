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
	- [Configuration](#configuration)
		-[Writer](#configure-writer)

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
(see below in [Configure Writer](#configure-writer)).
`WriterConf` has methods:

- `method name(){...}` -
- `clone-with-name($name){...}` -
- `self-check(){}` - 
- `make-writer(){...}`
- `close(){...}`

## Filter

`Filter` is responsible to decide allow the corresponding `Writer` to write log
or not. It has three methods:

- `do-before($context){...}` - some code which decides allow log or not.
If the method returns False the log are forbidden; otherwise True;
- `reactive-level(){}` - in most cases filtering can be done only by
log level. This method will be called before `do-before` method. If the method
returns False the log are forbidden; otherwise True;
- `do-after($context){}` - 

`Filter` creates by `FilterConf` - a configuration object which contains all
necessary information and algorithm for creating a concrete `Filter` instance.
(see below in [Configure Filter](#configure-filter)).

## NDC

## MDC

Cliche:
-------

## Logger


Logger Wrapper:
---------------

## Synchronisation of configuration and Logger instance

Configuration:
--------------
Изменения вступают в силу сразу.

AUTHOR
======

Mikhail Khorkov <atroxaper@cpan.org>

Source can be located at: https://github.com/TODO . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Mikhail Khorkov

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.