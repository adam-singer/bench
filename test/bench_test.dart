
library bench_test;

import 'package:unittest/unittest.dart';

part '../lib/bench_part.dart';

void main() {
  testBench();
}

void testBench() { 
  group('testBench', () {
    test('testBenchmarkConstructor', testBenchmarkConstructor);
    test('testBenchmarkAsyncConstructor', testBenchmarkAsyncConstructor);
    test('testBenchmarkConstructorZeroMeasureThrows', testBenchmarkConstructorZeroMeasureThrows);
    test('testBenchmarkConstructorNegativeWarmupThrows', testBenchmarkConstructorNegativeWarmupThrows);
    test('testBenchmarkAsyncConstructorNoFutureThrows', testBenchmarkAsyncConstructorNoFutureThrows);
    test('testBenchmarkNoWarmupOneMeasure', testBenchmarkNoWarmupOneMeasure);
  });
}

void testBenchmarkConstructor() {
  var method = () {};
  var benchmark = new Benchmark(method, warmup:42, measure:7, 
      description:'snarf');
  expect(benchmark.method, same(method));
  expect(benchmark.warmup, equals(42));
  expect(benchmark.measure, equals(7));
  expect(benchmark.description, equals('snarf'));
  expect(benchmark.isAsync, isFalse);  
}

void testBenchmarkAsyncConstructor() {
  var method = Future async() {};
  var benchmark = new Benchmark.async(method, warmup:42, measure:7, 
      description:'async_snarf');
  expect(benchmark.method, same(method));
  expect(benchmark.warmup, equals(42));
  expect(benchmark.measure, equals(7));
  expect(benchmark.description, equals('async_snarf'));
  expect(benchmark.isAsync, isTrue);  
}

void testBenchmarkConstructorZeroMeasureThrows() {
  expect(() => new Benchmark((){}, warmup:1, measure:0), 
      throwsA(const isInstanceOf<ArgumentError>()));
}

void testBenchmarkConstructorNegativeWarmupThrows() {
  expect(() => new Benchmark((){}, warmup:-1, measure:6), 
      throwsA(const isInstanceOf<ArgumentError>()));
}

void testBenchmarkAsyncConstructorNoFutureThrows() {
  expect(() => new Benchmark.async(void sync() {}), throws);
}

void testBenchmarkNoWarmupOneMeasure() {
  int count = 0;
  
  var benchmark = new Benchmark(() {    
    count++;
  }, warmup:0, measure:1);
  
  benchmark._run().then(expectAsync1((ignore) {
    expect(count, equals(1));
  }));
}
