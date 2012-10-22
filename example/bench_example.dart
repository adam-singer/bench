
library bench_example;

import 'package:logging/logging.dart';
import 'package:bench/bench.dart';

void main() {
  
  Logger.root.on.record.add((record) => print('${record.message}'));
  
  new Benchmarker().run(libraryIterations:50);
}

Benchmark benchSomething() {
  // TODO: set something up
  return () { 
    // TODO: benchmark something
  };
}
