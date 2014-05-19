# General
This directory contains the dm_logger library which can be used for log output in any vala program.

# Read log files
To read and print a log file you can use the dm_logreader:
```
dm_logreader -m <mdb-file> -L <log-file>
```
# Usage
## In your program
You have to do the following steps to use the dm_logger-library:
```vala
using DMLogger;
```

## Compilation
When you use the library you have to do a preprocessing step before compiling your programs:
```
preprocess_logger.pl <directory containing your vala files> <mdb-file>
