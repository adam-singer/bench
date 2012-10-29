Bench
=====

A micro benchmark library for [dart][dl].

Bench uses the MIT license as described in the LICENSE file.

Bench uses [semantic versioning][sv].

Benchmarking for Dart
---------------------

There has been a fair amount of [discussion][misc] lately regarding 
[benchmarking of code on the Dart VM][benchmarking].  Bench was written with
the goal of making it easy to quickly write reliable benchmark functions for
the Dart VM.

Usage
-----

- See the [examples][ex] for usage.

Known Issues
------------

- Bench uses [mirrors][mirrors] which are currently not supported by dart2js.
- Bench must be run in the same isolate as the benchmark functions; this
requirement may be lifted in the future, although remote invocations don't
necessarily make sense for benchmarking so that may never be supported.

[benchmarking] : http://www.dartlang.org/articles/benchmarking/
[dl] : http://www.dartlang.org/
[ex] : https://github.com/rmsmith/bench/blob/master/example/bench_example.dart
[mirrors] : http://api.dartlang.org/docs/bleeding_edge/dart_mirrors.html
[misc] : https://groups.google.com/a/dartlang.org/group/misc/
[sv] : http://semver.org/