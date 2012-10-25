
library bench_example;

import 'package:logging/logging.dart';
import 'package:bench/bench.dart';

void main() {
  
  Logger.root.on.record.add((record) => print('${record.message}'));
  
  new Benchmarker().run();
}

Benchmark pollardRho() {
  // http://en.wikipedia.org/wiki/Pollard's_rho_algorithm
  
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
  
  return new Benchmark(() {
    rho(n);
  }, iterations:2, description:"Pollard's rho algorithm for n: ${n}");
}
