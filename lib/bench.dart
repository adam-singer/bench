
/// A library for executing micro benchmark functions.
library bench;

import 'dart:mirrors';

import 'package:logging/logging.dart';

class Benchmark {  
  final Function method;
  final String description;
  final int iterations;
  
  Benchmark(void method(), {this.description:"", this.iterations:100})
      : method = method;
  
  // TODO: we could have a named ctor for .async  
}

Logger _logger = new Logger('bench');

/// Internal representation of a benchmark method.
class _BenchmarkMethod {
  
  final MethodMirror method;
  final Stopwatch stopwatch;
  
  int _iterations; // TODO: use annotation once available
  
  _BenchmarkMethod(this.method)
      : stopwatch = new Stopwatch();
  
  Future run(LibraryMirror library) {
    var completer = new Completer();
    _setup(library).then((closure) {
      stopwatch.start();
      _runBenchmark(closure).then((x) {
        stopwatch.stop();
        completer.complete(null);
      });
    });
    return completer.future;
  }
  
  Future _runBenchmark(ClosureMirror closure, [int count=0]) {
    var completer = new Completer();
    closure.apply([]).then((x) {
      if(++count == _iterations) completer.complete(null);
      else _runBenchmark(closure, count).then((x) => completer.complete(null));
    });
    return completer.future;
  }
  
  Future<ClosureMirror> _setup(LibraryMirror library) {    
    var completer = new Completer();
    library.invoke(method.simpleName, []).then((benchmark) {
      benchmark.getField('iterations').then((instance) {
        _iterations = instance.reflectee;
        
        // TODO: reflect description
        
        benchmark.getField('method').then((closure) {
          completer.complete(closure);
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
  
  factory _BenchmarkLibrary.check(LibraryMirror library, int iterations) {
    var benchmarkLibrary = 
        new _BenchmarkLibrary._parse(library, iterations);
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
    // TODO: sort benchmarks for consistency
    _logger.fine('${library.qualifiedName} : ${benchmarks.length} benchmarks');
  }
    
  Future run([int count=0]) {
    var completer = new Completer();
    // TODO: randomize the benchmarks each iteration using List.sort()
    _runBenchmarks().then((x) {
      if(++count == iterations) completer.complete(null);
      else run(count).then((x) => completer.complete(null));
    });
    return completer.future;
  }
  
  Future _runBenchmarks([Iterator it = null]) {
    var completer = new Completer();
    if(it == null) it = benchmarks.iterator();
    var benchmark = it.next();
    benchmark.run(library).then((x) {
      if(!it.hasNext()) completer.complete(null);
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
    _logger.info('running benchmarker');
    _initialize(iterations);
    _runLibraries().then((x) {
      _report();
    });
  }

  void _addLibrary(LibraryMirror library, int iterations) {    
    var benchmarkLibrary = new _BenchmarkLibrary.check(library, iterations);
    if(benchmarkLibrary != null) _libraries.add(benchmarkLibrary);
  }
  
  void _initialize(int iterations) {
    if(!_isInitialized) {
      currentMirrorSystem().libraries.getValues().forEach((library) {
        _addLibrary(library, iterations);
      });
      // TODO: sort libraries for consistency
    }
  }
  
  void _report() {
    _libraries.forEach((library) {
      library.benchmarks.forEach((benchmark) {
        var iterations = library.iterations * benchmark._iterations;
        var averageMs = benchmark.stopwatch.elapsedInMs() ~/ iterations;
        _logger.info('${benchmark.method.qualifiedName} : '
            '(${benchmark.stopwatch.elapsedInMs()} ms / '
            '${iterations} iterations) = $averageMs');  
      });
    });
  }
  
  Future _runLibraries([Iterator it = null]) {
    var completer = new Completer();
    if(it == null) it = _libraries.iterator();
    if(!it.hasNext()) completer.complete(null);
    else {
      it.next().run().then((x) {      
        _runLibraries(it).then((x) => completer.complete(null));
      });
    }
    return completer.future;
  }
}
