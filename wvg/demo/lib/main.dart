import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wvg/wvg.dart';

void main() {
  runApp(const MaterialApp(home: Material(child: MyApp())));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<Wvg> wvg = <Wvg>[];

  double _value = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AssetBundle bundle = DefaultAssetBundle.of(context);
    bundle.load('samples/action-info.wvg').then(_add);
    bundle.load('samples/cross.wvg').then(_add);
    bundle.load('samples/first.wvg').then(_add);
    bundle.load('samples/heart.wvg').then(_add);
    bundle.load('samples/slider.wvg').then(_add);
    bundle.load('samples/overlap.wvg').then(_add);
    bundle.load('samples/video-005.wvg').then(_add);
    bundle.load('samples/check.wvg').then(_add);
  }

  void _add(ByteData data) {
    if (!mounted)
      return;
    setState(() {
      wvg.add(Wvg(data));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              children: wvg.map((Wvg wvg) => Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: 200.0,
                  height: 200.0,
                  child: FittedBox(
                    child: SizedBox(
                      width: wvg.width,
                      height: wvg.height,
                      child: CustomPaint(
                        painter: Test(wvg),
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
        Slider(
          min: -0.1,
          max: 1.1,
          value: _value,
          label: _value.toStringAsFixed(2),
          onChanged: (double value) {
            setState(() {
              _value = value;
              for (Wvg image in wvg) {
                if (image.parameterCount > 0)
                  image.updateDoubleParameter(0, value);
              }
            });
          }
        ),
      ],
    );
  }
}

class Test extends CustomPainter {
  Test(this.wvg);

  final Wvg wvg;

  @override
  void paint(Canvas canvas, Size size) {
    wvg.paint(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(Test oldDelegate) => wvg.isDirty;
}
