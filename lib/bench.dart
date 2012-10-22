
/// A library for executing micro benchmark functions.
library bench;

import 'dart:mirrors';

import 'package:logging/logging.dart';

typedef void Benchmark();

/// TODO: async benchmarks are not yet supported, coming soon!
typedef Future BenchmarkAsync();

Logger _logger = new Logger('bench');

/// Internal representation of a benchmark method.
class _BenchmarkMethod {
  
  final MethodMirror method;  
  final String description; // TODO: allow this to be set via annotation
  final int iterations; // TODO: allow this to be set via annotation
  final Stopwatch stopwatch;
  
  _BenchmarkMethod(this.method, {this.description:"", this.iterations:1000})
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
      if(++count == iterations) completer.complete(null);
      else _runBenchmark(closure, count).then((x) => completer.complete(null));
    });
    return completer.future;
  }
  
  Future<ClosureMirror> _setup(LibraryMirror library) {    
    var completer = new Completer();
    library.invoke(method.simpleName, []).then((closure) {
      completer.complete(closure);
    });    
    return completer.future;
  }
}

/// Internal representation of a library containing 1 or more benchmark methods.
class _BenchmarkLibrary {
  
  final LibraryMirror library;
  final List<_BenchmarkMethod> benchmarks;
  final int iterations; // TODO: allow this to be set via annotation
  
  factory _BenchmarkLibrary.verify(LibraryMirror library) {
    var benchmarkLibrary = new _BenchmarkLibrary._parse(library);
    if(benchmarkLibrary.benchmarks.length > 0) return benchmarkLibrary;    
    return null;
  }
  
  _BenchmarkLibrary._parse(this.library, {this.iterations:100})
      : benchmarks = new List<_BenchmarkMethod>() {
    _logger.fine('parsing library ${library.qualifiedName} for benchmarks');        
    for(var method in library.functions.getValues()) {            
      if(method.isTopLevel) {
        // TODO: look for annotation instead of using naming convention
        if(method.simpleName.startsWith('bench')
            && method.parameters.length == 0
            // TODO: is there a better way to validate the returnType?
            && method.returnType is TypedefMirror
            && method.returnType.qualifiedName.startsWith('bench.Benchmark')) {
          
          _logger.finer("found benchmark method: ${method.simpleName}");            
          benchmarks.add(new _BenchmarkMethod(method));
        }
      }
    }
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
        
  Future run() {
    _logger.info('running benchmarker');
    _initialize();
    _runLibraries().then((x) {
      _report();
    });
  }

  void _addLibrary(LibraryMirror library) {    
    var benchmarkLibrary = new _BenchmarkLibrary.verify(library);
    if(benchmarkLibrary != null) _libraries.add(benchmarkLibrary);
  }
  
  void _initialize() {
    if(!_isInitialized) {
      currentMirrorSystem().libraries.getValues().forEach((library) {
        _addLibrary(library);
      });
    }
  }
  
  void _report() {
    // TODO: sort alphabetically for consistent report
    _libraries.forEach((library) {
      // TODO: sort alphabetically for consistent report
      library.benchmarks.forEach((benchmark) {
        var iterations = library.iterations * benchmark.iterations;
        _logger.info('${benchmark.method.qualifiedName} took '
            '${benchmark.stopwatch.elapsedInMs()} ms for '
            '${iterations} iterations');  
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
