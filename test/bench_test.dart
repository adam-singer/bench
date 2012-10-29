
library bench_test;

import 'dart:isolate';
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
    test('testBenchmarkAsyncNoWarmupOneMeasure', testBenchmarkAsyncNoWarmupOneMeasure);
    test('testBenchmarkSeveralIterations', testBenchmarkSeveralIterations);
    test('testBenchmarkAsyncSeveralIterations', testBenchmarkAsyncSeveralIterations);
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
  expect(benchmark.elapsedMilliseconds, isZero);
  expect(benchmark.elapsedMicroseconds, isZero);
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
  expect(benchmark.elapsedMilliseconds, isZero);
  expect(benchmark.elapsedMicroseconds, isZero);
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
  
  var benchmark = new Benchmark(() => ++count, warmup:0, measure:1);
  
  benchmark._run().then(expectAsync1((ignore) {
    expect(count, equals(1));
  }));
}

void testBenchmarkAsyncNoWarmupOneMeasure() {
  int count = 0;  
  
  var benchmark = new Benchmark.async(() {    
    var completer = new Completer();
    new Timer(50, (t) {
      count++;
      completer.complete(null);
    });
    return completer.future;    
  }, warmup:0, measure:1);
  
  benchmark._run().then(expectAsync1((ignore) {
    expect(count, equals(1));
    expect(benchmark.elapsedMilliseconds, greaterThan(49));
    expect(benchmark.elapsedMicroseconds, greaterThan(49999));
  }));
}

void testBenchmarkSeveralIterations() {
  int count = 0;  
  
  var benchmark = new Benchmark(() => ++count, warmup:42, measure:24);
  
  benchmark._run().then(expectAsync1((ignore) {
    expect(count, equals(66));
  }));
}

void testBenchmarkAsyncSeveralIterations() {
  int count = 0;  
  
  var benchmark = new Benchmark.async(() {    
    var completer = new Completer();
    new Timer(50, (t) {
      count++;
      completer.complete(null);
    });
    return completer.future;    
  }, warmup:6, measure:4);
  
  benchmark._run().then(expectAsync1((ignore) {
    expect(count, equals(10));
    expect(benchmark.elapsedMilliseconds, greaterThan(199));
    expect(benchmark.elapsedMilliseconds, lessThan(201));
    expect(benchmark.elapsedMicroseconds, greaterThan(199999));
    expect(benchmark.elapsedMilliseconds, lessThan(201000));
  }));
}
