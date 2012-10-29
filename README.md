Bench
=====

A micro benchmark library for [dart](http://www.dartlang.org/).

Bench uses the MIT license as described in the LICENSE file.

Bench uses [semantic versioning](http://semver.org/).

Benchmarking for Dart
---------------------

There has been a fair amount of [discussion]
(https://groups.google.com/a/dartlang.org/group/misc/) lately regarding 
[benchmarking of code on the Dart VM]
(http://www.dartlang.org/articles/benchmarking/).  Bench was written with
the goal of making it easy to quickly write reliable benchmark functions for
the Dart VM.

Usage
-----

- See the [examples]
(https://github.com/rmsmith/bench/blob/master/example/bench_example.dart).

Known Issues
------------

- Bench uses [mirrors]
(http://api.dartlang.org/docs/bleeding_edge/dart_mirrors.html) which are 
currently not supported by dart2js.
- Bench must be run in the same isolate as the benchmark functions; remote
invocations of a benchmark function may not make sense, but could be supported.
- Bench currently runs *all* of the Benchmark functions in the isolate; we plan
to make this more configurable.
