
/// A library for executing micro benchmark functions.
library bench;

import 'dart:mirrors';
import 'package:logging/logging.dart';

Logger _logger = new Logger('bench');

/// Representation of a [Benchmark].
class Benchmark {
  
  /// Gets the [Function] to invoke each iteration of the [Benchmark].
  final Function method;
  
  /// Gets a description of the [Benchmark].
  final String description;
  
  /// Gets the number of measured iterations to execute for the [Benchmark].
  final int measure;
  
  /// Gets the number of warmup iterations to execute for the [Benchmark].
  final int warmup;
  
  /// Constructs a new [Benchmark] with the given synchronous [method] and
  /// the optional [description], [measure] count, and [warmup] count.
  Benchmark(void method(), {this.description:"", this.measure:100, 
      this.warmup:200}) : method = method;
  
  /// Constructs a new [Benchmark] with the given asynchronous [method] and
  /// the optional [descripton], [measure] count, and [warmup] count.
  Benchmark.async(Future method(), {this.description:"", this.measure:100, 
      this.warmup:200}) : method = method;
}

/// A [Benchmarker] is capable of discovering all of the [Benchmark]s in the
/// current isolate's [MirrorSystem] and running them in a configurable manner.
class Benchmarker {
  
  final List<_BenchmarkLibrary> _libraries;
  bool _isInitialized = false;
  
  /// Constructs a new [Benchmarker].
  Benchmarker() : _libraries = new List<_BenchmarkLibrary>();

  /// Runs all of the [Benchmark]s for a number of global [iterations]; the
  /// [iterations] are a multiplier for all [Benchmark]s in the isolate.
  Future run({int iterations:1}) {
    _initialize(iterations);
    _logger.info('running benchmarks');
    _runLibraries().then((x) => _report());
  }

  void _addLibrary(LibraryMirror library, int iterations) {    
    var benchmarkLibrary = new _BenchmarkLibrary(library, iterations);
    if(benchmarkLibrary != null) _libraries.add(benchmarkLibrary);
  }
  
  void _initialize(int iterations) {
    if(!_isInitialized) {
      var mirrors = currentMirrorSystem();
      _logger.info('initializing isolate: ${mirrors.isolate.debugName}');
      mirrors.libraries.getValues().forEach((library) 
          => _addLibrary(library, iterations));
    }
  }
  
  // TODO: provide an API for custom result parsing / reporting
  void _report() {
    _libraries.forEach((library) {
      library._benchmarks.forEach((benchmark) {
        var iterations = library._iterations * benchmark._measure;
        var averageMs = benchmark._stopwatch.elapsedInMs() / iterations;
        _logger.info('${benchmark._method.qualifiedName} : '
            '(${benchmark._stopwatch.elapsedInMs()} ms / '
            '${iterations} iterations) = $averageMs');  
      });
    });
  }
  
  Future _runLibraries([Iterator it = null]) {
    var completer = new Completer();
    if(it == null) it = _libraries.iterator();
    if(!it.hasNext) completer.complete(null);
    else it.next()._run().then((x) 
        => _runLibraries(it).then((x) => completer.complete(null)));
    return completer.future;
  }
}

/// Internal representation of a library containing 1 or more benchmark methods.
class _BenchmarkLibrary {
  
  final LibraryMirror _library;
  final List<_BenchmarkMethod> _benchmarks;
  final int _iterations;
  
  factory _BenchmarkLibrary(LibraryMirror library, int iterations) {
    var benchmarkLibrary = new _BenchmarkLibrary._parse(library, iterations);
    if(benchmarkLibrary._benchmarks.length > 0) return benchmarkLibrary;    
    return null;
  }
  
  _BenchmarkLibrary._parse(this._library, this._iterations)
      : _benchmarks = new List<_BenchmarkMethod>() {
    _logger.fine('parsing library ${_library.qualifiedName} for benchmarks');        
    for(var method in _library.functions.getValues()) {            
      if(method.isTopLevel) {
        if(method.parameters.length == 0
            && method.returnType is ClassMirror
            && method.returnType.qualifiedName == 'bench.Benchmark') {
          
          _logger.finer("found benchmark method: ${method.simpleName}");
          _benchmarks.add(new _BenchmarkMethod(method));
        }
      }
    }
    _logger.fine('${_library.qualifiedName} : ${_benchmarks.length} benchmarks');
  }
    
  Future _run([int index=0]) {
    var completer = new Completer();
    // TODO: randomize the benchmarks order each iteration?
    _runBenchmarks().then((x) {
      if(++index == _iterations) completer.complete(null);
      else _run(index).then((x) => completer.complete(null));
    });
    return completer.future;
  }
  
  Future _runBenchmarks([Iterator it = null]) {
    var completer = new Completer();
    if(it == null) it = _benchmarks.iterator();
    var benchmark = it.next();
    benchmark._run(_library).then((x) {
      if(!it.hasNext) completer.complete(null);
      else _runBenchmarks(it).then((x) => completer.complete(null));
    });
    return completer.future;
  }
}

/// Internal representation of a benchmark method.
/// TODO: can we roll this functionality into the [Benchmark] ?
/// It has mostly the same fields, so we might be able to write a static
/// method 'Future<Benchmark> _reflect(InstanceMirror)' to build it.
/// Another benefit of merging it into the public [Benchmark] is that it could
/// double as the 'result' object (i.e. we can have a getter for elapsedMs/Us)
class _BenchmarkMethod {
  
  final MethodMirror _method;
  final Stopwatch _stopwatch;
  
  String _description;
  int _measure;
  int _warmup;
  bool _isAsync;
  
  _BenchmarkMethod(this._method)
      : _stopwatch = new Stopwatch();
  
  Future _run(LibraryMirror library) {
    var completer = new Completer();
    _setup(library).then((closure) {
      _runBenchmark(closure, _warmup).then((x) {
        _stopwatch.start();
        _runBenchmark(closure, _measure).then((x) {
          _stopwatch.stop();
          completer.complete(null);
        });
      });
    });
    return completer.future;
  }
  
  Future _runBenchmark(ClosureMirror closure, int count, [int index=0]) {
    var completer = new Completer();
    closure.apply([]).then((instance) {
      Future advance() {
        if(++index == count) completer.complete(null);
        else _runBenchmark(closure, count, index).then((x) 
            => completer.complete(null));
      }
      // this only works in the current isolate, since reflectee is !simple
      if(_isAsync) instance.reflectee.then((x) => advance());
      else advance();    
    });
    return completer.future;
  }
  
  Future<ClosureMirror> _setup(LibraryMirror library) {    
    var completer = new Completer();
    library.invoke(_method.simpleName, []).then((benchmark) {
      benchmark.getField('description').then((instance) {
        _description = instance.reflectee;
        benchmark.getField('measure').then((instance) {
          _measure = instance.reflectee;
          benchmark.getField('warmup').then((instance) {
            _warmup = instance.reflectee;
            benchmark.getField('method').then((instance) {
              ClosureMirror closure = instance;
              // TODO: if returnType is 'dynamic' this is ambiguous
              _isAsync = closure.function.returnType.simpleName == 'Future';            
              completer.complete(closure);
            });
          });
        });
      });
    });
    return completer.future;
  }
}
