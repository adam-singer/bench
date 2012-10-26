
/// A library for executing micro benchmark functions.
library bench;

import 'dart:mirrors';

import 'package:logging/logging.dart';

Logger _logger = new Logger('bench');

/**
 * Benchmark metadata.  
 * This will likely be replaced by annotations once mirrors support them.
 */
class Benchmark {  
  final Function method;
  final String description;
  final int iterations;
  
  Benchmark(void method(), {this.description:"", this.iterations:100})
      : method = method;
  
  Benchmark.async(Future method(), {this.description:"", this.iterations:100})
      : method = method;
}

/// Internal representation of a benchmark method.
class _BenchmarkMethod {
  
  final MethodMirror _method;
  final Stopwatch _stopwatch;
  
  String _description; // TODO: use annotation once available
  int _iterations; // TODO: use annotation once available  
  bool _isAsync;
  
  _BenchmarkMethod(this._method)
      : _stopwatch = new Stopwatch();
  
  Future run(LibraryMirror library) {
    var completer = new Completer();
    _setup(library).then((closure) {
      
      // TODO: warmup
      
      _stopwatch.start();
      _runBenchmark(closure).then((x) {
        _stopwatch.stop();
        completer.complete(null);
      });
    });
    return completer.future;
  }
  
  Future _runBenchmark(ClosureMirror closure, [int index=0]) {
    var completer = new Completer();
    closure.apply([]).then((instance) {
      Future advance() {
        if(++index == _iterations) completer.complete(null);
        else _runBenchmark(closure, index).then((x) => completer.complete(null));
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
        benchmark.getField('iterations').then((instance) {
          _iterations = instance.reflectee;
          benchmark.getField('method').then((instance) {
            ClosureMirror closure = instance;
            // TODO: if returnType is 'dynamic' this is ambiguous
            _isAsync = closure.function.returnType.simpleName == 'Future';            
            completer.complete(closure);
          });
        });
      });
    });
    return completer.future;
  }
}

/// Internal representation of a library containing 1 or more benchmark methods.
class _BenchmarkLibrary {
  
  final LibraryMirror library;
  final List<_BenchmarkMethod> benchmarks;
  final int iterations; // TODO: allow this to be set via annotation
  
  factory _BenchmarkLibrary(LibraryMirror library, int iterations) {
    var benchmarkLibrary = new _BenchmarkLibrary._parse(library, iterations);
    if(benchmarkLibrary.benchmarks.length > 0) return benchmarkLibrary;    
    return null;
  }
  
  _BenchmarkLibrary._parse(this.library, this.iterations)
      : benchmarks = new List<_BenchmarkMethod>() {
    _logger.fine('parsing library ${library.qualifiedName} for benchmarks');        
    for(var method in library.functions.getValues()) {            
      if(method.isTopLevel) {
        if(method.parameters.length == 0
            && method.returnType is ClassMirror
            && method.returnType.qualifiedName == 'bench.Benchmark') {
          
          _logger.finer("found benchmark method: ${method.simpleName}");
          benchmarks.add(new _BenchmarkMethod(method));
        }
      }
    }
    _logger.fine('${library.qualifiedName} : ${benchmarks.length} benchmarks');
  }
    
  Future run([int index=0]) {
    var completer = new Completer();
    // TODO: randomize the benchmarks order each iteration?
    _runBenchmarks().then((x) {
      if(++index == iterations) completer.complete(null);
      else run(index).then((x) => completer.complete(null));
    });
    return completer.future;
  }
  
  Future _runBenchmarks([Iterator it = null]) {
    var completer = new Completer();
    if(it == null) it = benchmarks.iterator();
    var benchmark = it.next();
    benchmark.run(library).then((x) {
      if(!it.hasNext) completer.complete(null);
      else _runBenchmarks(it).then((x) => completer.complete(null));
    });
    return completer.future;
  }
}

class Benchmarker {
  
  final List<_BenchmarkLibrary> _libraries;
  bool _isInitialized = false;
  
  Benchmarker() : _libraries = new List<_BenchmarkLibrary>();
        
  Future run({int iterations:1}) {    
    _initialize(iterations);
    _logger.info('running benchmarks');
    _runLibraries().then((x) {
      _report();
    });
  }

  void _addLibrary(LibraryMirror library, int iterations) {    
    var benchmarkLibrary = new _BenchmarkLibrary(library, iterations);
    if(benchmarkLibrary != null) _libraries.add(benchmarkLibrary);
  }
  
  void _initialize(int iterations) {
    if(!_isInitialized) {
      var mirrors = currentMirrorSystem();
      _logger.info('initializing isolate: ${mirrors.isolate.debugName}');
      mirrors.libraries.getValues().forEach((library) {
        _addLibrary(library, iterations);
      });
    }
  }
  
  // TODO: provide an API for custom result parsing / reporting
  void _report() {
    _libraries.forEach((library) {
      library.benchmarks.forEach((benchmark) {
        var iterations = library.iterations * benchmark._iterations;
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
    else {
      it.next().run().then((x) {      
        _runLibraries(it).then((x) => completer.complete(null));
      });
    }
    return completer.future;
  }
}
