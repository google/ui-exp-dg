// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery/battery.dart';

//const Duration pauseDelay = Duration(seconds: 5);
//const Duration maxDuration = Duration(seconds: 30);
const Duration pauseDelay = Duration(minutes: 5);
const Duration maxDuration = Duration(minutes: 30);

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp();

  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _busy = false;

  void _runBenchmark({ BuildContext context, Benchmark benchmark }) async {
    try {
      setState(() { _busy = true; });
      BenchmarkResults results;
      try {
        results = await benchmark.run();
      } finally {
        setState(() { _busy = false; });
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return ResultsDialog(
            label: benchmark.name,
            results: results,
          );
        },
      );
    } on BenchmarkException catch (error) {
      await showMessage(context, error.message);
    }
  }

  Future<void> showMessage(BuildContext context, String message) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          children: <Widget>[
            Text(message),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        appBar: AppBar(title: Text('GC benchmark')),
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text('Status: ${ _busy ? "Busy..." : "Idle" }'),
                  OutlineButton(
                    child: Text('IMMUTABLE DART'),
                    onPressed: () => _runBenchmark(context: context, benchmark: ImmutableDartBenchmark()),
                  ),
                  OutlineButton(
                    child: Text('NOGC DART'),
                    onPressed: () => _runBenchmark(context: context, benchmark: NoGCDartBenchmark()),
                  ),
                  OutlineButton(
                    child: Text('IMMUTABLE KOTLIN'),
                    onPressed: () => _runBenchmark(context: context, benchmark: PlatformBenchmark('kotlin.immutable')),
                  ),
                  OutlineButton(
                    child: Text('NOGC KOTLIN'),
                    onPressed: () => _runBenchmark(context: context, benchmark: PlatformBenchmark('kotlin.nogc')),
                  ),
                  OutlineButton(
                    child: Text('ALL (in order)'),
                    onPressed: () async {
                      try {
                        showMessage(context, 'Benchmarks running; device should be in airplane mode, idle, disconnected from power, and should not be touched or moved for the duration of the test (several hours).');
                        print('benchmark script started...');
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r1 = await ImmutableDartBenchmark().run();
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r2 = await NoGCDartBenchmark().run();
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r3 = await PlatformBenchmark('kotlin.immutable').run();
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r4 = await PlatformBenchmark('kotlin.nogc').run();
                        print('benchmarks done');
                        await showDialog<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return SimpleDialog(
                              title: Text('Benchmark results'),
                              contentPadding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
                              children: <Widget>[
                                Text('$r1'),
                                Text('$r2'),
                                Text('$r3'),
                                Text('$r4'),
                              ],
                            );
                          },
                        );
                      } on BenchmarkException catch (error) {
                        print(error);
                        await showMessage(context, error.message);
                      }
                    },
                  ),
                  OutlineButton(
                    child: Text('ALL (reverse order)'),
                    onPressed: () async {
                      try {
                        showMessage(context, 'Benchmarks running; device should be in airplane mode, idle, disconnected from power, and should not be touched or moved for the duration of the test (several hours).');
                        print('benchmark script started...');
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r4 = await PlatformBenchmark('kotlin.nogc').run();
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r3 = await PlatformBenchmark('kotlin.immutable').run();
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r2 = await NoGCDartBenchmark().run();
                        await Future.delayed(pauseDelay);
                        final BenchmarkResults r1 = await ImmutableDartBenchmark().run();
                        print('benchmarks done');
                        await showDialog<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return SimpleDialog(
                              title: Text('Benchmark results'),
                              contentPadding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
                              children: <Widget>[
                                Text('$r1'),
                                Text('$r2'),
                                Text('$r3'),
                                Text('$r4'),
                              ],
                            );
                          },
                        );
                      } on BenchmarkException catch (error) {
                        print(error);
                        await showMessage(context, error.message);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ResultsDialog extends StatelessWidget {
  ResultsDialog({ this.label, this.results });

  final String label;

  final BenchmarkResults results;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text('Benchmark results: $label'),
      contentPadding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
      children: <Widget>[
        Text('Per cycle time (smaller is better): ${results.perCycleTime.toStringAsFixed(1)}ns'),
        Text('Normalized battery capacity (bigger is better): ${results.normalizedBatteryCapacity.toStringAsFixed(1)} cycles'),
        Text('Total cycles: ${results.count}'),
        Text('Total time: ${results.time}'),
        Text('Battery usage: ${results.batteryStart}% -> ${results.batteryEnd}% = ${results.batteryDelta}%'),
      ],
    );
  }
}

class BenchmarkException implements Exception {
  const BenchmarkException(this.message);
  final String message;
}

class BenchmarkResults {
  BenchmarkResults(this.name, this.time, this.count, this.batteryStart, this.batteryEnd);

  final String name;
  final Duration time;
  final int count;
  final int batteryStart;
  final int batteryEnd;

  // in nanoseconds
  double get perCycleTime => (1000.0 * time.inMicroseconds) / count;

  int get batteryDelta => batteryEnd - batteryStart;

  double get normalizedBatteryCapacity => (count / -batteryDelta) * 100.0;

  @override
  String toString() {
    return '$name: $count cycles over $time (${perCycleTime}ns per cycle); battery $batteryStart% -> $batteryEnd% = $batteryDelta% (capacity $normalizedBatteryCapacity cycles)';
  }
}

abstract class Benchmark {
  String get name;

  @nonVirtual
  Future<BenchmarkResults> run() async {
    print('Starting $name...');
    final Battery battery = Battery();
    bool powered = false;
    final StreamSubscription<BatteryState> subscription = battery.onBatteryStateChanged.listen((BatteryState state) {
      if (state != BatteryState.discharging)
        powered = true;
    });
    await setup();
    final int batteryStart = await battery.batteryLevel;
    Stopwatch stopwatch = Stopwatch()..start();
    int count;
    if (!powered)
      count = await loop();
    stopwatch.stop();
    final int batteryEnd = await battery.batteryLevel;
    subscription.cancel();
    if (powered)
      throw BenchmarkException('Device was powered during benchmark.');
    final BenchmarkResults results = BenchmarkResults(name, stopwatch.elapsed, count, batteryStart, batteryEnd);
    print(results);
    return results;
  }

  @protected
  Future<void> setup() async { }

  @protected
  Future<int> loop();
}

const int kArraySize = 1000000;
const int kTightLoop = 10000;

class IntBox {
  IntBox(this.value);
  final int value;
}

class ImmutableDartBenchmark extends Benchmark {
  @override
  String get name => 'dart.immutable';

  List<IntBox> array;
  final Random random = Random(0);

  @override
  Future<void> setup() async {
    array = List.generate(kArraySize, (int index) => IntBox(random.nextInt(kArraySize)));
  }

  @override
  Future<int> loop() async {
    int count = 0;
    Stopwatch stopwatch = Stopwatch()..start();
    do {
      for (int step = 0; step < kTightLoop; step += 1) {
        count += 1;
        final int index = array[count % kArraySize].value + step;
        array[index % kArraySize] = IntBox(count % kArraySize);
      }
      await null;
    } while (stopwatch.elapsed < maxDuration);
    return count;
  }
}

class NoGCDartBenchmark extends Benchmark {
  @override
  String get name => 'dart.nogc';

  List<IntBox> array;
  List<IntBox> backup;
  final Random random = Random(0);

  @override
  Future<void> setup() async {
    array = List.generate(kArraySize, (int index) => IntBox(random.nextInt(kArraySize)));
    backup = array.toList();
  }

  IntBox copy(int index) => backup[index];

  @override
  Future<int> loop() async {
    int count = 0;
    Stopwatch stopwatch = Stopwatch()..start();
    do {
      for (int step = 0; step < kTightLoop; step += 1) {
        count += 1;
        final int index = array[count % kArraySize].value + step;
        array[index % kArraySize] = copy(count % kArraySize);
      }
      await null;
    } while (stopwatch.elapsed < maxDuration);
    return count;
  }
}

class PlatformBenchmark extends Benchmark {
  PlatformBenchmark(this.name);

  final String name;

  MethodChannel channel;

  @override
  Future<void> setup() async {
    channel = MethodChannel('gc.damowmow.com/$name');
    await channel.invokeMethod('setup');
  }

  @override
  Future<int> loop() async {
    return await channel.invokeMethod('loop');
  }
}
