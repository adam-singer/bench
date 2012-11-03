
library bench_test;

import 'dart:isolate';
import 'dart:mirrors';
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

part 'package:bench/src/bench_part.dart';

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
    test('testBenchmarkLibraryConstructor', testBenchmarkLibraryConstructor);
    test('testBenchmarkLibraryInitializeNoBenchmark', testBenchmarkLibraryInitializeNoBenchmark);
    test('testBenchmarkLibraryInitializeSingleBenchmark', testBenchmarkLibraryInitializeSingleBenchmark);
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
    expect(benchmark.elapsedMicroseconds, greaterThan(199999));
  }));
}

void testBenchmarkLibraryConstructor() {  
  var mockLibraryMirror = new MockLibraryMirror();
  mockLibraryMirror.qualifiedName = 'snarf';  
  var library = new BenchmarkLibrary._(mockLibraryMirror);
  expect(library._mirror, equals(mockLibraryMirror));
  expect(library.benchmarks, isEmpty);
  expect(library.qualifiedName, equals('snarf'));  
}

void testBenchmarkLibraryInitializeNoBenchmark() {
    
  var mockReturnType = new MockClassMirror();
  mockReturnType.qualifiedName = 'bench.Benchmark_NOT';
  
  var mockMethod = new MockMethodMirror();
  mockMethod.isTopLevel = true;
  mockMethod.qualifiedName = 'snarf';
  mockMethod.returnType = mockReturnType;
  
  var mockLibraryMirror = new MockLibraryMirror();
  mockLibraryMirror.functions['snarf'] = mockMethod;
    
  var library = new BenchmarkLibrary._(mockLibraryMirror);
  
  library._initialize().then(expectAsync1((ignore) {   
    expect(mockLibraryMirror.invokeCount, isZero);
    expect(library.benchmarks, isEmpty);
  }));
}

void testBenchmarkLibraryInitializeSingleBenchmark() {
  
  var mockReturnType = new MockClassMirror();
  mockReturnType.qualifiedName = 'bench.Benchmark';
  
  var mockMethod = new MockMethodMirror();
  mockMethod.isTopLevel = true;
  mockMethod.qualifiedName = 'setup';
  mockMethod.returnType = mockReturnType;
  
  var mockLibraryMirror = new MockLibraryMirror();
  mockLibraryMirror.functions['setup'] = mockMethod;
  
  var benchmark = new Benchmark(() {});
  var instance = new MockInstanceMirror();
  instance.reflectee = benchmark;
  mockLibraryMirror.invokeReturnValues['setup'] = instance;
  
  var library = new BenchmarkLibrary._(mockLibraryMirror);
  
  library._initialize().then(expectAsync1((ignore) {   
    expect(mockLibraryMirror.invokeCount, equals(1));
    expect(mockLibraryMirror.invokeCounts['setup'], equals(1));
    expect(library.benchmarks.length, equals(1));
    expect(library.benchmarks[0], equals(benchmark));
  }));
}

// TODO: the following set of hand rolled mocks should be replaced by the Mock
// class in the unittest library of the SDK if and when that becomes reliable

class MockClassMirror implements ClassMirror {
  Map<String, MethodMirror> constructors = new Map<String, MethodMirror>();
  final ClassMirror defaultFactory = null;
  Map<String, MethodMirror> getters = new Map<String, MethodMirror>();
  bool isClass = true;
  bool isOriginalDeclaration;
  bool isPrivate;
  bool isTopLevel;
  SourceLocation location;  
  Map<String, Mirror> members = new Map<String, Mirror>();
  Map<String, MethodMirror> methods = new Map<String, MethodMirror>();
  MirrorSystem mirrors;
  ClassMirror originalDeclaration;
  DeclarationMirror owner;
  String qualifiedName;
  Map<String, MethodMirror> setters = new Map<String, MethodMirror>();
  String simpleName;
  ClassMirror superclass;
  List<ClassMirror> superinterfaces = new List<ClassMirror>();
  Map<String, TypeMirror> typeArguments = new Map<String, TypeMirror>();
  Map<String, TypeVariableMirror> typeVariables = 
      new Map<String, TypeVariableMirror>();
  Map<String, VariableMirror> variables = new Map<String, VariableMirror>();
  Future<InstanceMirror> getField(String fieldName) {
    throw new UnsupportedError('getField');
  }
  Future<InstanceMirror> invoke(String memberName, 
      List<Object> positionalArguments, [Map<String, Object> namedArguments]) {
    throw new UnsupportedError('invoke');
  }
  Future<InstanceMirror> newInstance(String constructorName, 
      List<Object> positionalArguments, [Map<String, Object> namedArguments]) {
    throw new UnsupportedError('newInstance');
  }
  Future<InstanceMirror> setField(String fieldName, Object value) {
    throw new UnsupportedError('setField');
  }
}

class MockDeclarationMirror implements DeclarationMirror {
  bool isPrivate;
  bool isTopLevel;
  SourceLocation location;
  MirrorSystem mirrors;
  DeclarationMirror owner;
  String qualifiedName;
  String get simpleName {
    int index = qualifiedName.lastIndexOf('.');
    return (index == -1) ? qualifiedName : qualifiedName.substring(index);    
  }
}

class MockInstanceMirror implements InstanceMirror {
  bool hasReflectee;
  MirrorSystem mirrors;
  dynamic reflectee;
  ClassMirror type;
  Future<InstanceMirror> getField(String fieldName) {
    throw new UnsupportedError('getField');
  }
  Future<InstanceMirror> invoke(String memberName, 
      List<Object> positionalArguments, [Map<String, Object> namedArguments]) {
    throw new UnsupportedError('invoke');
  }
  Future<InstanceMirror> setField(String fieldName, Object value) {
    throw new UnsupportedError('setField');
  }
}

class MockMethodMirror extends MockDeclarationMirror implements 
    MethodMirror {
  String constructorName;
  bool isAbstract;
  bool isConstConstructor;
  bool isConstructor;
  bool isFactoryConstructor;
  bool isGenerativeConstructor;
  bool isGetter;
  bool isOperator;
  bool isRedirectingConstructor;
  bool isRegularMethod;
  bool isSetter;
  bool isStatic;
  List<ParameterMirror> parameters = new List<ParameterMirror>();
  TypeMirror returnType;
}

class MockLibraryMirror extends MockDeclarationMirror implements
    LibraryMirror {
  Map<String, ClassMirror> classes = new Map<String, ClassMirror>();
  Map<String, MethodMirror> functions = new Map<String, MethodMirror>();
  Map<String, MethodMirror> getters = new Map<String, MethodMirror>();
  Map<String, Mirror> members = new Map<String, Mirror>();
  Map<String, MethodMirror> setters = new Map<String, MethodMirror>();
  String url;
  Map<String, VariableMirror> variables = new Map<String, VariableMirror>();
  Future<InstanceMirror> getField(String fieldName) {
    throw new UnsupportedError('getField');
  }
  
  Map<String, int> invokeCounts = new Map<String, int>();
  Map<String, InstanceMirror> invokeReturnValues = 
      new Map<String, InstanceMirror>();
  
  int get invokeCount {
    int count = 0;
    invokeCounts.forEach((k, v) {
      count += v;
    });
    return count;
  }
  
  Future<InstanceMirror> invoke(String memberName, 
      List<Object> positionalArguments, [Map<String, Object> namedArguments]) {    
    var completer = new Completer<InstanceMirror>();
    
    if(!invokeCounts.containsKey(memberName)) {
      invokeCounts[memberName] = 0;
    }
    invokeCounts[memberName]++;

    completer.complete(invokeReturnValues[memberName]);
    return completer.future;
  }
  
  Future<InstanceMirror> setField(String fieldName, Object value) {
    throw new UnsupportedError('setField');
  }
}

