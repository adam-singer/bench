
library bench_example;

import 'dart:isolate';
import 'package:bench/bench.dart';
import 'package:logging/logging.dart';

void main() {
  
  // Bench logs to a Logger named 'bench'; you may use the logging API to
  // change the log level and add handlers to that logger or the root logger.
  Logger.root.on.record.add((record) => print('${record.message}'));
  
  // Create and run() a Benchmarker object; this will detect all of the
  // top-level functions in the current isolate which meet the criteria:
  //    - the function must return a Benchmark
  //    - the function must have no arguments
  // You may optionally pass a number of global iterations to run for all
  // benchmark functions in the isolate.
  new Benchmarker().run();
}

/// This is an example of a synchronous Benchmark with setup
/// see http://en.wikipedia.org/wiki/Pollard's_rho_algorithm
Benchmark pollardRho() {
  
  // Perform your setup code in this scope; it will be executed once per
  // iteration of the entire library.
  
  int gcd(int a, int b) {
    while(b > 0) {
      int t = a;
      a = b;
      b = t % b;
    }
    return a;
  }
  
  int rho(int n) {
    int a = 2;
    int b = 2;
    int d = 1;
    while(d == 1) {
      a = (a*a + 1) % n;
      b = (b*b + 1) % n;
      b = (b*b + 1) % n;
      d = gcd((a-b).abs(),n);
    }
    return d;
  }
  
  int n = 329569479697;
  
  // Return a Benchmark object that encapsulates the information bench will
  // need in order to perform your benchmark.
  return new Benchmark(
      () => rho(n), // The function that will be called for each iteration
      warmup:1, // The number of warmup iterations that you want   
      measure:2, // The number of measured iterations that you want
      description:"Pollard's rho algorithm for n: ${n}"); // A description
}

/// This is an example of an asynchronous Benchmark without any setup
/// Notice that we are using the [Benchmark.async] constructor to indicate this.
Benchmark timer() => new Benchmark.async(
    // The function for asynchronous benchmarks returns a Future
    Future async() {
      
  var completer = new Completer();
  
  // The timer callback will complete the Future and that will trigger bench to 
  // advance to the next iteration of the benchmark or finish.
  new Timer(1500, (t) => completer.complete(null));
  
  return completer.future;
}, warmup:5, measure:5, description:"Asynchronous 1.5 second timer");
