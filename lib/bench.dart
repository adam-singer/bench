
/// A library for executing micro benchmark functions.
library bench;

import 'dart:mirrors';
import 'package:logging/logging.dart';

Logger _logger = new Logger('bench');

/// Representation of a [Benchmark].
class Benchmark {
  
  /// Gets a description of the [Benchmark].
  final String description;
  
  /// Gets the elapsed time in milliseconds over all measured iterations.
  int get elapsedMilliseconds => _stopwatch.elapsedInMs();
  
  /// Gets the elapsed time in microseconds over all measured iterations.
  int get elapsedMicroseconds => _stopwatch.elapsedInUs();
  
  /// Gets whether or not this [Benchmark] is asynchronous.
  final bool isAsync;
  
  /// Gets the number of measured iterations to execute for the [Benchmark].
  final int measure;
  
  /// Gets the [Function] to invoke each iteration of the [Benchmark].
  final Function method;
  
  /// Gets the qualified name of the [method] if available.
  String get methodName => (_mirror == null) ? "" : _mirror.qualifiedName;
  
  /// Gets the number of warmup iterations to execute for the [Benchmark].
  final int warmup;
  
  final Stopwatch _stopwatch;    
  MethodMirror _mirror;
  
  /// Constructs a new [Benchmark] with the given synchronous [method] and
  /// the optional [description], [measure] count, and [warmup] count.
  Benchmark(void method(), {this.description:"", this.measure:100, 
      this.warmup:200}) 
      : method = method
      , isAsync = false
      , _stopwatch = new Stopwatch();
  
  /// Constructs a new [Benchmark] with the given asynchronous [method] and
  /// the optional [descripton], [measure] count, and [warmup] count.
  Benchmark.async(Future method(), {this.description:"", this.measure:100, 
      this.warmup:200}) 
      : method = method
      , isAsync = true
      , _stopwatch = new Stopwatch();
  
  Future _iterate(int count, [int index=0]) {
    var completer = new Completer();    
    Future advance() {
      if(++index == count) completer.complete(null);
      else _iterate(count, index).then((x) => completer.complete(null));
    }    
    if(isAsync) {
      method().then((x) => advance());
    } else {
      method();
      advance();
    }    
    return completer.future;
  }
  
  Future _run() {
    var completer = new Completer();
    _iterate(warmup).then((x) {
      _stopwatch.start();
      _iterate(measure).then((x) {
        _stopwatch.stop();
        completer.complete(null);
      });
    });
    return completer.future;
  }
}

/// Represents a library containing one or more [Benchmark]s.
class BenchmarkLibrary {
  
  /// Gets the list of [Benchmark]s in the library.
  final List<Benchmark> benchmarks; // TODO: expose a read-only view
  
  /// Gets the qualified name of the library.
  String get qualifiedName => _mirror.qualifiedName;
  
  final LibraryMirror _mirror;
  
  BenchmarkLibrary._(this._mirror) : benchmarks = new List<Benchmark>();
  
  Future _initialize([Iterator<MethodMirror> it = null]) {
    var completer = new Completer();
    if(it == null) it = _mirror.functions.getValues().iterator();
    if(!it.hasNext) completer.complete(null);
    else {
      var method = it.next();
      if(method.isTopLevel 
          && method.parameters.length == 0
          && method.returnType is ClassMirror
          && method.returnType.qualifiedName == 'bench.Benchmark') {          
        _logger.finer("found benchmark method: ${method.simpleName}");          
        _mirror.invoke(method.simpleName, []).then((instance) {            
          // this only works in the current isolate as it is! simple
          Benchmark benchmark = instance.reflectee;
          benchmark._mirror = method;
          benchmarks.add(benchmark);
        });
      }
      _initialize(it).then((x) => completer.complete(null));
    }    
    return completer.future;
  }
  
  Future _run([Iterator<Benchmark> it = null]) {
    var completer = new Completer();
    if(it == null) it = benchmarks.iterator();
    var benchmark = it.next();
    _logger.fine('running benchmark: ${benchmark.methodName}');
    benchmark._run().then((x) {
      if(!it.hasNext) completer.complete(null);
      else _run(it).then((x) => completer.complete(null));
    });
    return completer.future;
  }
}

/// Represents the result of one run of a [Benchmarker].
class BenchmarkResult {
  
  /// Gets the number of global iterations for the run result.
  final int iterations;
  
  /// Gets the list of libraries containing benchmarks for the run result.
  final List<BenchmarkLibrary> libraries; // TODO: expose a read-only view
  
  BenchmarkResult._(this.iterations) : libraries = new List<BenchmarkLibrary>();
}

/// A [BenchmarkHandler] function to process a given benchmark [result].
typedef void BenchmarkHandler(BenchmarkResult result);

/// A [BenchmarkHandler] function that logs the [result] to bench's logger.
void benchmarkResultLogger(BenchmarkResult result) {
  result.libraries.forEach((library) {
    library.benchmarks.forEach((benchmark) {
      var iterations = result.iterations * benchmark.measure;
      var averageMs = benchmark._stopwatch.elapsedInMs() / iterations;
      _logger.info('${benchmark.methodName} : '
      '(${benchmark._stopwatch.elapsedInMs()} ms / '
      '${iterations} iterations) = $averageMs');  
    });
  });
}

/// A [Benchmarker] is capable of discovering all of the [Benchmark]s in the
/// current isolate's [MirrorSystem] and running them in a configurable manner.
class Benchmarker {
  
  /// Constructs a new [Benchmarker].
  Benchmarker();

  /// Runs all of the [Benchmark]s for a number of global [iterations]; the
  /// [iterations] are a multiplier for all [Benchmark]s in the isolate.
  Future<BenchmarkResult> run({int iterations:1, 
      BenchmarkHandler handler:benchmarkResultLogger}) {
    var completer = new Completer<BenchmarkResult>();    
    var result = new BenchmarkResult._(iterations);
    _initialize(result).then((result) {
      _run(result).then((result) {
        if(handler != null) handler(result);
        completer.complete(result);
      });
    });
    return completer.future;
  }
   
  Future<BenchmarkResult> _initialize(BenchmarkResult result) {
    var completer = new Completer();
    var mirrors = currentMirrorSystem();
    _logger.info('initializing isolate: ${mirrors.isolate.debugName}');      
    _initializeLibraries(mirrors.libraries.getValues().iterator(), 
        result.libraries).then((x) {
          completer.complete(result);
        });
    return completer.future;
  }
  
  Future _initializeLibraries(Iterator<LibraryMirror> it, 
                              List<BenchmarkLibrary> libraries) {    
    var completer = new Completer();
    if(!it.hasNext) completer.complete(null);
    else {
      var library = new BenchmarkLibrary._(it.next());
      library._initialize().then((x) {        
        _logger.fine('${library.qualifiedName} : found '
            '${library.benchmarks.length} benchmarks');        
        if(library.benchmarks.length > 0) libraries.add(library);        
        _initializeLibraries(it, libraries).then((x) => completer.complete(null));
      });
    }
    return completer.future;
  }
  
  Future<BenchmarkResult> _run(BenchmarkResult result, [int index=0]) {
    var completer = new Completer();
    _runLibraries(result.libraries.iterator()).then((x) {
      if(++index == result.iterations) completer.complete(result);
      else _run(result, index).then((x) => completer.complete(result));
    });
    return completer.future;
  }
  
  Future _runLibraries(Iterator<BenchmarkLibrary> it) {
    var completer = new Completer();
    if(!it.hasNext) completer.complete(null);
    else {
      var library = it.next();
      _logger.fine('running library: ${library.qualifiedName}');
      library._run().then((x) 
          => _runLibraries(it).then((x) => completer.complete(null)));
    }   
    return completer.future;
  }
}
