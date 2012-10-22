
library bench_example;

import 'package:logging/logging.dart';
import 'package:bench/bench.dart';

void main() {
  
  Logger.root.on.record.add(logPrinter);
  
  new Benchmarker().run(libraryIterations:50);
}

void logPrinter(LogRecord record) {
  print('${record.message}');
}

Benchmark benchSomething() {
  // TODO: set something up
  return () { 
    // TODO: benchmark something
  };
}
