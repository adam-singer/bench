
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
  
  /// Gets the elapsed time in milliseconds over all measured iterations.
  int get elapsedMilliseconds => _stopwatch.elapsedInMs();
  
  /// Gets the elapsed time in microseconds over all measured iterations.
  int get elapsedMicroseconds => _stopwatch.elapsedInUs();
  
  /// Gets the qualified name of the [method] if available.
  String get methodName => (_mirror == null) ? "" : _mirror.qualifiedName;
  
  final Stopwatch _stopwatch;  
  final bool _isAsync;  
  MethodMirror _mirror;
  
  /// Constructs a new [Benchmark] with the given synchronous [method] and
  /// the optional [description], [measure] count, and [warmup] count.
  Benchmark(void method(), {this.description:"", this.measure:100, 
      this.warmup:200}) 
      : method = method
      , _stopwatch = new Stopwatch()
      , _isAsync = false;
  
  /// Constructs a new [Benchmark] with the given asynchronous [method] and
  /// the optional [descripton], [measure] count, and [warmup] count.
  Benchmark.async(Future method(), {this.description:"", this.measure:100, 
      this.warmup:200}) 
      : method = method
      , _stopwatch = new Stopwatch()
      , _isAsync = true;
  
  Future _iterate(int count, [int index=0]) {
    var completer = new Completer();    
    Future advance() {
      if(++index == count) completer.complete(null);
      else _iterate(count, index).then((x) => completer.complete(null));
    }    
    if(_isAsync) {
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
  
  // TODO: should expose a read-only view (Sequence?)
  final List<Benchmark> benchmarks;
  
  String get qualifiedName => _mirror.qualifiedName;
  
  final LibraryMirror _mirror;
  
  BenchmarkLibrary(this._mirror) : benchmarks = new List<Benchmark>();
  
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

/// A [Benchmarker] is capable of discovering all of the [Benchmark]s in the
/// current isolate's [MirrorSystem] and running them in a configurable manner.
class Benchmarker {
  
  // TODO: should expose a read-only view (Sequence?)
  // NO, this should be private and we'll just publich a BenchmarkResult that
  // contains a Sequence
  final List<BenchmarkLibrary> libraries;
  
  // TODO: remove this field and put it in the BenchmarkResult
  int _iterations;
  
  /// Constructs a new [Benchmarker].
  Benchmarker() : libraries = new List<BenchmarkLibrary>();

  /// Runs all of the [Benchmark]s for a number of global [iterations]; the
  /// [iterations] are a multiplier for all [Benchmark]s in the isolate.
  Future run({int iterations:1}) {
    _iterations = iterations;

    // TODO: this method should create a new BenchmarkResult and return it
    // via the Future<BenchmarkResult> ... so the Benchmarker will be stateless
    
    _initialize().then((x) => _run().then((x) => _report()));
  }
   
  Future _initialize() {
    var completer = new Completer();
    if(_isInitialized) completer.complete(null);      
    else {
      var mirrors = currentMirrorSystem();
      _logger.info('initializing isolate: ${mirrors.isolate.debugName}');      
      _initializeLibraries(mirrors.libraries.getValues().iterator()).then((x) {
        _isInitialized = true;
        completer.complete(null);
      });
    }
    return completer.future;
  }
  
  Future _initializeLibraries(Iterator<LibraryMirror> it) {
    var completer = new Completer();
    if(!it.hasNext) completer.complete(null);
    else {
      var library = new BenchmarkLibrary(it.next());
      library._initialize().then((x) {        
        _logger.fine('${library.qualifiedName} : found '
            '${library.benchmarks.length} benchmarks');        
        if(library.benchmarks.length > 0) libraries.add(library);        
        _initializeLibraries(it).then((x) => completer.complete(null));
      });
    }
    return completer.future;
  }
  
  Future _run([int index=0]) {
    var completer = new Completer();
    _runLibraries().then((x) {
      if(++index == _iterations) completer.complete(null);
      else _run(index).then((x) => completer.complete(null));
    });
    return completer.future;
  }
  
  Future _runLibraries([Iterator<BenchmarkLibrary> it = null]) {
    var completer = new Completer();
    if(it == null) it = libraries.iterator();
    if(!it.hasNext) completer.complete(null);
    else {
      var library = it.next();
      _logger.fine('running library: ${library.qualifiedName}');
      library._run().then((x) 
          => _runLibraries(it).then((x) => completer.complete(null)));
    }   
    return completer.future;
  }
  
  // TODO: provide an API for custom result parsing / reporting?
  void _report() {
    libraries.forEach((library) {
      library.benchmarks.forEach((benchmark) {
        var iterations = _iterations * benchmark.measure;
        var averageMs = benchmark._stopwatch.elapsedInMs() / iterations;
        _logger.info('${benchmark.methodName} : '
            '(${benchmark._stopwatch.elapsedInMs()} ms / '
            '${iterations} iterations) = $averageMs');  
      });
    });
  }
}
