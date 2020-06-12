// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'dart:ui';

void main() {
  runApp(LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) => MyHomePage(constraints.biggest),
  ));
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    print('build: ${timings.first.buildDuration.inMilliseconds}ms');
    print('raster: ${timings.first.rasterDuration.inMilliseconds}ms');
    print('total: ${timings.first.totalSpan.inMilliseconds}ms');
    print('--');
  });
}

class MyHomePage extends StatefulWidget {
  MyHomePage(this.size, {Key key}) : super(key: key);

  final Size size;

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
    var r = math.Random(0);
    var children = <Widget>[];
    for (int index = 0; index < 10000; index += 1) {
      switch (r.nextInt(2)) {
        case 0:
          final double radius = r.nextDouble() * math.min(widget.size.width, widget.size.height) / 8;
          final Offset center = Offset(r.nextDouble() * (widget.size.width - radius), r.nextDouble() * (widget.size.height - radius));
          final Rect rect = Rect.fromCircle(center: center, radius: radius);
          children.add(
            Positioned.fromRect(
              rect: rect,
              child: Container(
                decoration: ShapeDecoration(
                  shape: CircleBorder(),
                  color: Color(0xFF000000 + r.nextInt(0x00FFFFFF)),
                ),
              ),
            ),
          );
          break;
        case 1:
          final double w = r.nextDouble() * widget.size.width / 4;
          final double h = r.nextDouble() * widget.size.height / 4;
          final double x = r.nextDouble() * (widget.size.width - w);
          final double y = r.nextDouble() * (widget.size.height - h);
          children.add(
            Positioned(
              left: x,
              top: y,
              width: w,
              height: h,
              child: Transform.rotate(
                angle: _angle * (r.nextDouble() * 2.0 - 1.0),
                child: Container(color: Color(r.nextInt(0xFFFFFFFF))),
              ),
            ),
          );
          break;
      }
    }
    return Stack(children: children, alignment: Alignment.center);
  }
}

