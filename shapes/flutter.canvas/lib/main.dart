// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'dart:ui';

void main() {
  runApp(MyHomePage());
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    print('build: ${timings.first.buildDuration.inMilliseconds}ms');
    print('raster: ${timings.first.rasterDuration.inMilliseconds}ms');
    print('total: ${timings.first.totalSpan.inMilliseconds}ms');
    print('--');
  });
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _angle = 0.0;
  Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: (1000 / 60).floor()), (timer) {
      setState(() {
        _angle += 0.01;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // this isn't a good way to do this in a real app but it matches
    // the hack in the kotlin/swift version
    return CustomPaint(
      painter: _Shapes(_angle),
    );
  }
}

class _Shapes extends CustomPainter {
  _Shapes(this.t);

  final double t;

  void paint(Canvas canvas, Size size) {
    var r = math.Random(0);
    for (int index = 0; index < 10000; index += 1) {
      switch (r.nextInt(2)) {
        case 0:
          final double radius = r.nextDouble() * math.min(size.width, size.height) / 8;
          canvas.drawCircle(
            Offset(r.nextDouble() * (size.width - radius), r.nextDouble() * (size.height - radius)),
            radius,
            Paint()
              ..color = Color(0xFF000000 + r.nextInt(0x00FFFFFF))
          );
          break;
        case 1:
          final double w = r.nextDouble() * size.width / 4;
          final double h = r.nextDouble() * size.height / 4;
          final double x = r.nextDouble() * (size.width - w);
          final double y = r.nextDouble() * (size.height - h);
          canvas.save();
          canvas.translate(x + w / 2, y + h / 2);
          canvas.rotate(t * (r.nextDouble() * 2.0 - 1.0));
          canvas.translate(-(x + w / 2), -(y + h / 2));
          canvas.drawRect(
            Rect.fromLTWH(x, y, w, h),
            Paint()
              ..color = Color(r.nextInt(0xFFFFFFFF))
          );
          canvas.restore();
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_Shapes oldDelegate) {
    return t != oldDelegate.t;
  }
}
