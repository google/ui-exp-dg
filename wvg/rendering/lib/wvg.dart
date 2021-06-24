import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:vector_math/vector_math_64.dart';

class Wvg {
  static const int blockSize = 64; // words
  static const int gradientSize = blockSize * 2; // words
  static const int matrixSize = 16; // words
  static const int shapeSize = 4; // words
  static const int wordSize = 4; // bytes

  static const int METADATA_BLOCKS = 0;
  static const int PARAM_BLOCKS = 7;
  static const int EXPR_BLOCKS = 15;
  static const int MATRIX_BLOCKS = 23;
  static const int CURVE_BLOCKS = 31;
  static const int SHAPE_BLOCKS = 35;
  static const int GRADIENT_BLOCKS = 43;
  static const int PAINT_BLOCKS = 47;
  static const int COMP_BLOCKS = 55;

  factory Wvg(ByteData file) {
    if (file.lengthInBytes % (blockSize * wordSize) > 0)
      throw const FormatException('File length is not an integral number of blocks and therefore cannot be a valid WVG file');
    if (Endian.host != Endian.little) {
      final ByteData convertedBytes = ByteData(file.lengthInBytes);
      for (int offset = 0; offset < file.lengthInBytes; offset += 4)
        convertedBytes.setUint32(offset, file.getUint32(offset, Endian.little), Endian.host);
      file = convertedBytes;
    }
    final Uint32List uint32s = file.buffer.asUint32List();
    final Float32List float32s = file.buffer.asFloat32List();

    if (uint32s.length < blockSize)
      throw const FormatException('File is too short to be a valid WVG file');
    if (uint32s[0] != 0x0A475657)
      throw const FormatException('WVG signature missing');

    final Uint32List BLOCK_SIZES = Uint32List.sublistView(uint32s, 1, blockSize);
    final Uint32List BLOCK_OFFSETS = Uint32List(blockSize - 1);
    int totalSize = 1;
    for (int index = 0; index < BLOCK_SIZES.length; index += 1) {
      BLOCK_OFFSETS[index] = totalSize * blockSize;
      totalSize += BLOCK_SIZES[index];
    }
    if (totalSize * blockSize != uint32s.length)
      throw const FormatException('File header does not match file length');

    double width, height;
    if (BLOCK_SIZES[METADATA_BLOCKS] > 0) {
      width = float32s[BLOCK_OFFSETS[METADATA_BLOCKS]];
      height = float32s[BLOCK_OFFSETS[METADATA_BLOCKS] + 1];
    } else {
      width = 1.0;
      height = 1.0;
    }

    final int PARAM_COUNT = BLOCK_SIZES[PARAM_BLOCKS] * blockSize;
    // The Uint32List.sublist() arguments are start and end in words.
    final Uint32List parameters = uint32s.sublist(BLOCK_OFFSETS[PARAM_BLOCKS], BLOCK_OFFSETS[PARAM_BLOCKS] + PARAM_COUNT);

    final int EXPR_COUNT = BLOCK_SIZES[EXPR_BLOCKS];
    // ByteBuffer.asByteData takes start and length in bytes.
    final ByteData expressions = file.buffer.asByteData(BLOCK_OFFSETS[EXPR_BLOCKS] * wordSize, EXPR_COUNT * blockSize * wordSize);
    final Uint32List expressionValues = Uint32List(EXPR_COUNT); // This is length in words.

    // ByteBuffer.asUint32List takes start in bytes and length in words.
    final Uint32List matrices = file.buffer.asUint32List(BLOCK_OFFSETS[MATRIX_BLOCKS] * wordSize, BLOCK_SIZES[MATRIX_BLOCKS] * blockSize);
    final Uint32List curves = file.buffer.asUint32List(BLOCK_OFFSETS[CURVE_BLOCKS] * wordSize, BLOCK_SIZES[CURVE_BLOCKS] * blockSize);
    final Uint32List shapes = file.buffer.asUint32List(BLOCK_OFFSETS[SHAPE_BLOCKS] * wordSize, BLOCK_SIZES[SHAPE_BLOCKS] * blockSize);
    final Uint32List gradients = file.buffer.asUint32List(BLOCK_OFFSETS[GRADIENT_BLOCKS] * wordSize, BLOCK_SIZES[GRADIENT_BLOCKS] * blockSize);
    final Uint32List paints = file.buffer.asUint32List(BLOCK_OFFSETS[PAINT_BLOCKS] * wordSize, BLOCK_SIZES[PAINT_BLOCKS] * blockSize);
    final Uint32List compositions = file.buffer.asUint32List(BLOCK_OFFSETS[COMP_BLOCKS] * wordSize, BLOCK_SIZES[COMP_BLOCKS] * blockSize);

    return Wvg._(width, height, parameters, EXPR_COUNT, expressions, expressionValues, matrices, curves, shapes, gradients, paints, compositions);
  }

  Wvg._(
    this.width,
    this.height,
    this._parametersAsUint32,
    this._EXPR_COUNT,
    this._expressions,
    this._resolvedExpressionsAsUint32,
    this._matricesAsUint32,
    this._curvesAsUint32,
    this._shapesAsUint32,
    this._gradientsAsUint32,
    this._paintsAsUint32,
    this._compositionsAsUint32,
  ) : _PARAM_COUNT = _parametersAsUint32.length,
      _parametersAsInt32 = _parametersAsUint32.buffer.asInt32List(_parametersAsUint32.offsetInBytes, _parametersAsUint32.length),
      _parametersAsFloat32 = _parametersAsUint32.buffer.asFloat32List(_parametersAsUint32.offsetInBytes, _parametersAsUint32.length),
      assert(_EXPR_COUNT == _expressions.lengthInBytes ~/ (blockSize * wordSize)),
      _resolvedExpressionsAsFloat32 = _resolvedExpressionsAsUint32.buffer.asFloat32List(_resolvedExpressionsAsUint32.offsetInBytes, _resolvedExpressionsAsUint32.length),
      _matricesAsFloat32 = _matricesAsUint32.buffer.asFloat32List(_matricesAsUint32.offsetInBytes, _matricesAsUint32.length),
      _MATRIX_COUNT = _matricesAsUint32.length ~/ matrixSize,
      _resolvedMatrices = List<Matrix4>.generate(_matricesAsUint32.length ~/ matrixSize, (int index) => Matrix4.identity()),
      _staticMatrices = BoolList.filled(_matricesAsUint32.length ~/ matrixSize, false),
      _curvesAsFloat32 = _curvesAsUint32.buffer.asFloat32List(_curvesAsUint32.offsetInBytes, _curvesAsUint32.length),
      _SHAPE_COUNT = _shapesAsUint32.length ~/ shapeSize,
      _GRADIENT_COUNT = _gradientsAsUint32.length ~/ gradientSize,
      _gradientsAsFloat32 = _gradientsAsUint32.buffer.asFloat32List(_gradientsAsUint32.offsetInBytes, _gradientsAsUint32.length),
      _PAINT_COUNT = _paintsAsUint32.length ~/ blockSize,
      _paints = List<ui.Paint>.generate(_paintsAsUint32.length ~/ blockSize, (int index) => ui.Paint()),
      _staticPaints = BoolList.filled(_paintsAsUint32.length ~/ blockSize, false),
      _COMPOSITION_COUNT = _compositionsAsUint32.length ~/ blockSize,
      _paths = List<ui.Path>.generate(_compositionsAsUint32.length ~/ blockSize, (int index) => ui.Path()),
      _staticPaths = BoolList.filled(_compositionsAsUint32.length ~/ blockSize, false),
      _resolvedPaints = List<ui.Paint>.generate(_compositionsAsUint32.length ~/ blockSize, (int index) => ui.Paint()),
      _staticResolvedPaints = BoolList.filled(_compositionsAsUint32.length ~/ blockSize, false);

  final double width;
  final double height;
  final int _PARAM_COUNT;
  final Uint32List _parametersAsUint32;
  final Int32List _parametersAsInt32;
  final Float32List _parametersAsFloat32;
  final int _EXPR_COUNT;
  final ByteData _expressions;
  final Uint32List _resolvedExpressionsAsUint32;
  final Float32List _resolvedExpressionsAsFloat32;
  final int _MATRIX_COUNT;
  final Uint32List _matricesAsUint32;
  final Float32List _matricesAsFloat32;
  final List<Matrix4> _resolvedMatrices;
  final BoolList _staticMatrices;
  final Uint32List _curvesAsUint32;
  final Float32List _curvesAsFloat32;
  final int _SHAPE_COUNT;
  final Uint32List _shapesAsUint32;
  final int _GRADIENT_COUNT;
  final Uint32List _gradientsAsUint32;
  final Float32List _gradientsAsFloat32;
  final int _PAINT_COUNT;
  final Uint32List _paintsAsUint32;
  final List<ui.Paint> _paints;
  final BoolList _staticPaints;
  final int _COMPOSITION_COUNT;
  final Uint32List _compositionsAsUint32;
  final List<ui.Path> _paths;
  final BoolList _staticPaths;
  final List<ui.Paint> _resolvedPaints;
  final BoolList _staticResolvedPaints;

  bool get isDirty => _dirty;
  bool _dirty = true;

  int get parameterCount => _PARAM_COUNT;

  void updateIntegerParameter(int parameter, int value) {
    if (parameter >= _parametersAsUint32.length)
      throw RangeError.index(parameter, updateIntegerParameter, 'parameters', null, _parametersAsUint32.length);
    if (value < 0) {
      _parametersAsInt32[parameter] = value;
    } else {
      _parametersAsUint32[parameter] = value;
    }
    _dirty = true;
  }

  void updateDoubleParameter(int parameter, double value) {
    if (parameter >= _parametersAsFloat32.length)
      throw RangeError.index(parameter, updateDoubleParameter, 'parameters', null, _parametersAsFloat32.length);
    _parametersAsFloat32[parameter] = value;
    _dirty = true;
  }

  void updateColorParameter(int parameter, ui.Color value) {
    if (parameter >= _parametersAsUint32.length)
      throw RangeError.index(parameter, updateColorParameter, 'parameters', null, _parametersAsUint32.length);
    final int argba = (value.value << 8) + (value.value >> 24);
    _parametersAsUint32[parameter] = argba; // automatically masked to 32bits
    _dirty = true;
  }

  void _recompute() {
    assert(_dirty);
    for (int index = 0; index < _EXPR_COUNT; index += 1)
      _resolvedExpressionsAsUint32[index] = _computeExpression(index);
    for (int index = 0; index < _MATRIX_COUNT; index += 1)
      _computeMatrix(index);
    for (int index = 0; index < _PAINT_COUNT; index += 1)
      _computePaint(index);
    for (int index = 0; index < _COMPOSITION_COUNT; index += 1)
      _computeComposition(index);
    _dirty = false;
  }

  int _computeExpression(int currentExpression) {
    final Uint32List expr = _expressions.buffer.asUint32List(_expressions.offsetInBytes + currentExpression * blockSize * wordSize, blockSize);
    final Uint32List stackAsUint32 = Uint32List(blockSize);
    final Int32List stackAsInt32 = stackAsUint32.buffer.asInt32List();
    final Float32List stackAsFloat32 = stackAsUint32.buffer.asFloat32List();
    int stackIndex = 0;
    loop: for (int exprIndex = 0; exprIndex < blockSize; exprIndex += 1) {
      assert(stackIndex < blockSize);
      final int command = expr[exprIndex];

      if (command < 0x80000000) { // high bit is zero
        stackAsUint32[stackIndex] = command;
        stackIndex += 1;

      } else if (command & 0xC0000000 == 0x80000000) { // highest two bits are 0b10
        // one-argument operator
        if (stackIndex < 1)
          continue;
        switch (command) {
          case 0x80000000: // integer negate
            stackAsInt32[stackIndex - 1] = -stackAsInt32[stackIndex - 1];
            break;
          case 0x80010000: // float negate
            stackAsFloat32[stackIndex - 1] = -stackAsFloat32[stackIndex - 1];
            break;
          case 0x80008000: // integer cast
            double arg = -stackAsFloat32[stackIndex - 1];
            if (!arg.isFinite || arg > 2147483647.0 || arg < -2147483648.0)
              arg = 0.0;
            stackAsInt32[stackIndex - 1] = arg.round(); // TODO(ianh): use roundEven once https://github.com/dart-lang/sdk/issues/46495 is fixed
            break;
          case 0x80018000: // float cast
            stackAsFloat32[stackIndex - 1] = stackAsInt32[stackIndex - 1].toDouble();
            break;
          case 0x80020000: // duplicate
            stackAsUint32[stackIndex] = stackAsUint32[stackIndex - 1];
            stackIndex += 1;
            break;
        }

      } else if (command & 0xE0000000 == 0xC0000000) { // highest three bits are 0b110
        // two-argument operator
        if (stackIndex < 2)
          continue;
        switch (command) {
          case 0xC0000001: // integer add
            stackAsInt32[stackIndex - 2] = stackAsInt32[stackIndex - 2] + stackAsInt32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0000002: // integer subtract
            stackAsInt32[stackIndex - 2] = stackAsInt32[stackIndex - 2] - stackAsInt32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0000003: // integer multiply
            stackAsInt32[stackIndex - 2] = stackAsInt32[stackIndex - 2] * stackAsInt32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0000004: // integer divide
            stackAsInt32[stackIndex - 2] = stackAsInt32[stackIndex - 2] ~/ stackAsInt32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0010001: // float add
            stackAsFloat32[stackIndex - 2] = stackAsFloat32[stackIndex - 2] + stackAsFloat32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0010002: // float subtract
            stackAsFloat32[stackIndex - 2] = stackAsFloat32[stackIndex - 2] - stackAsFloat32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0010003: // float multiply
            stackAsFloat32[stackIndex - 2] = stackAsFloat32[stackIndex - 2] * stackAsFloat32[stackIndex - 1];
            stackIndex -= 1;
            break;
          case 0xC0010004: // float divide
            stackAsFloat32[stackIndex - 2] = stackAsFloat32[stackIndex - 2] / stackAsFloat32[stackIndex - 1];
            stackIndex -= 1;
            break;
        }

      } else if (command & 0xFFC00000 == 0xFFC00000) { // highest 10 bets are set
        // zero-argument operator
        if (command == 0xFFC00000) { // terminate
          break loop;
        }
        if (command & 0xFFFF0000 == 0xFFD00000) { // parameter reference
          final int arg = command & 0x0000FFFF; // lower 16 bits
          if (arg >= _PARAM_COUNT) {
            stackAsUint32[stackIndex] = 0;
          } else {
            stackAsUint32[stackIndex] = _parametersAsUint32[arg];
          }
          stackIndex += 1;
        } else if (command & 0xFFFF0000 == 0xFFE00000) { // expression reference
          final int arg = command & 0x0000FFFF; // lower 16 bits
          if (arg >= currentExpression) {
            stackAsUint32[stackIndex] = 0;
          } else {
            stackAsUint32[stackIndex] = _resolvedExpressionsAsUint32[arg];
          }
          stackIndex += 1;
        }

      } else {
        // ignored
      }
    }
    if (stackIndex == 0) {
      assert(stackAsUint32[0] == 0);
      stackIndex += 1;
    }
    return stackAsUint32[stackIndex - 1];
  }

  static final Matrix4 _identityMatrix = Matrix4.identity();

  void _computeMatrix(int index) {
    assert(index < _MATRIX_COUNT);
    if (_staticMatrices[index])
      return;
    final Matrix4 target = _resolvedMatrices[index];
    bool isStatic = true;
    final int offset = index * matrixSize;
    for (int cell = 0; cell < matrixSize; cell += 1) {
      double valueAsFloat32 = _matricesAsFloat32[offset + cell];
      if (valueAsFloat32.isNaN) {
        final int valueAsUint32 = _matricesAsUint32[offset + cell];
        final int arg = valueAsUint32 & 0x0000FFFF;
        final int mode = valueAsUint32 >> 16;
        switch (mode) {
          case 0xFFD0:
            isStatic = false;
            valueAsFloat32 = arg < _PARAM_COUNT ? _parametersAsFloat32[arg] : 0.0;
            break;
          case 0xFFE0:
            isStatic = false;
            valueAsFloat32 = arg < _EXPR_COUNT ? _resolvedExpressionsAsFloat32[arg] : 0.0;
            break;
        }
      }
      target[cell] = valueAsFloat32;
    }
    if (isStatic)
      _staticMatrices[index] = true;
  }

  void _computePaint(int index) {
    assert(index < _MATRIX_COUNT);
    if (_staticPaints[index])
      return;
    final ui.Paint target = _paints[index];
    bool isStatic = true;
    final int offset = index * blockSize;
    final int type = _paintsAsUint32[offset];
    if (type & 0x00000010 > 0) {
      // gradient of some sort
      final int gradientIndex = _paintsAsUint32[offset + 1];
      final List<double> stops = <double>[];
      final List<ui.Color> colors = <ui.Color>[];
      if (gradientIndex < _GRADIENT_COUNT) {
        final int stopOffset = gradientIndex * 2 * blockSize;
        final int colorOffset = stopOffset + blockSize;
        double lastStop = 0.0;
        for (int stopIndex = 0; stopIndex < blockSize; stopIndex += 1) {
          final double nextStop;
          if (stopIndex == 0) {
            nextStop = 0.0;
          } else {
            double valueAsFloat32 = _gradientsAsFloat32[stopOffset + stopIndex];
            if (valueAsFloat32.isNaN) {
              final int valueAsUint32 = _gradientsAsUint32[stopOffset + stopIndex];
              final int arg = valueAsUint32 & 0x0000FFFF;
              final int mode = valueAsUint32 >> 16;
              switch (mode) {
                case 0xFFD0:
                  isStatic = false;
                  valueAsFloat32 = arg < _PARAM_COUNT ? _parametersAsFloat32[arg] : 0.0;
                  break;
                case 0xFFE0:
                  isStatic = false;
                  valueAsFloat32 = arg < _EXPR_COUNT ? _resolvedExpressionsAsFloat32[arg] : 0.0;
                  break;
              }
            }
            if ((lastStop < 1.0 && (valueAsFloat32.isNaN || valueAsFloat32 > 1.0)) || (stopIndex >= 63))
              valueAsFloat32 = 1.0;
            nextStop = valueAsFloat32;
            if (nextStop < lastStop || nextStop.isNaN || nextStop > 1.0)
              break;
          }
          lastStop = nextStop;
          int color = _gradientsAsUint32[colorOffset + stopIndex];
          final int arg = color & 0x0000FFFF;
          final int mode = color >> 16;
          switch (mode) {
            case 0xFFD0:
              isStatic = false;
              color = arg < _PARAM_COUNT ? _parametersAsUint32[arg] : 0;
              break;
            case 0xFFE0:
              isStatic = false;
              color = arg < _EXPR_COUNT ? _resolvedExpressionsAsUint32[arg] : 0;
              break;
            default:
              color = 0;
              break;
          }
          stops.add(nextStop);
          colors.add(_createColor(color));
        }
      } else {
        colors.add(const ui.Color(0x00000000));
        colors.add(const ui.Color(0x00000000));
        stops.add(0.0);
        stops.add(1.0);
      }
      final int FLAGS = _paintsAsUint32[offset + 2];
      final ui.TileMode tileMode = ui.TileMode.values[FLAGS & 0x03];
      final int matrixIndex = _paintsAsUint32[offset + 3];
      final Matrix4 matrix = matrixIndex < _MATRIX_COUNT ? _resolvedMatrices[matrixIndex] : _identityMatrix;
      if (isStatic && matrixIndex < _MATRIX_COUNT)
        isStatic = _staticMatrices[matrixIndex];
      switch (type) {
        case 0x00000010: // linear gradient
          target.shader = ui.Gradient.linear(
            ui.Offset.zero,
            const ui.Offset(1.0, 0.0),
            colors,
            stops,
            tileMode,
            matrix.storage,
          );
          break;
        case 0x00000014: // radial gradient
          target.shader = ui.Gradient.radial(
            ui.Offset.zero,
            1.0,
            colors,
            stops,
            tileMode,
            matrix.storage,
          );
          break;
        default:
          target.color = const ui.Color(0x00000000);
      }
    } else {
      // doesn't represent anything
      target.color = const ui.Color(0x00000000);
    }
    if (isStatic)
      _staticPaints[index] = true;
  }

  void _computeComposition(int index) {
    assert(index < _COMPOSITION_COUNT);
    final int offset = index * blockSize;
    if (!_staticPaths[index]) {
      final ui.Path target = _paths[index]..reset();
      bool isStatic = true;
      final int matrixIndex = _compositionsAsUint32[offset + 0];
      final int shapeIndex = _compositionsAsUint32[offset + 1];
      final int sequenceLength = _compositionsAsUint32[offset + 2];
      for (int sequenceIndex = 0; sequenceIndex <= sequenceLength; sequenceIndex += 1)
        isStatic = isStatic && _addPath(target, shapeIndex + sequenceIndex, matrixIndex + sequenceIndex);
      if (isStatic)
        _staticPaths[index] = true;
    }
    if (!_staticResolvedPaints[index]) {
      final int operator = _compositionsAsUint32[offset + 3];
      final int color = _compositionsAsUint32[offset + 4];
      _resolvePaint(index, operator, color);
    }
  }

  static final ui.Path _path = ui.Path();
  static final Uint32List _cellsAsUint32 = Uint32List(7);
  static final Float32List _cellsAsFloat32 = _cellsAsUint32.buffer.asFloat32List();

  // returns whether the given shape is static or not
  bool _addPath(ui.Path target, int shapeIndex, int matrixIndex) {
    if (shapeIndex >= _SHAPE_COUNT)
      return true;
    bool isStatic = true;
    final int offset = shapeIndex * shapeSize;
    final int SHAPE_GROUP_OFFSET = _shapesAsUint32[offset + 0];
    final int SHAPE_START_CURVE_INDEX = _shapesAsUint32[offset + 1];
    final int SHAPE_CURVE_COUNT = _shapesAsUint32[offset + 2];
    final int SHAPE_GROUP_SIZE = _shapesAsUint32[offset + 3];
    final int LENGTH = SHAPE_START_CURVE_INDEX + SHAPE_CURVE_COUNT; // this is in words, not blocks like in the spec
    if ((SHAPE_GROUP_OFFSET * blockSize < _curvesAsUint32.length) &&
        (SHAPE_START_CURVE_INDEX < blockSize) &&
        (SHAPE_GROUP_OFFSET * blockSize + LENGTH * SHAPE_GROUP_SIZE < _curvesAsUint32.length) &&
        (SHAPE_GROUP_SIZE >= 5) &&
        (SHAPE_GROUP_SIZE <= blockSize)) {
      for (int curveIndex = SHAPE_START_CURVE_INDEX; curveIndex < SHAPE_START_CURVE_INDEX + SHAPE_CURVE_COUNT; curveIndex += 1) {
        final int GROUP = curveIndex ~/ 64; // in groups
        final int GROUP_OFFSET = SHAPE_GROUP_OFFSET + GROUP * SHAPE_GROUP_SIZE; // in blocks
        assert(GROUP_OFFSET < _curvesAsUint32.length ~/ blockSize);
        for (int cell = 0; cell < _cellsAsUint32.length; cell += 1) {
          if (cell >= SHAPE_GROUP_SIZE) {
            _cellsAsUint32[cell] = 0xFFFFFFFF;
            continue;
          }
          final int cellIndex = (GROUP_OFFSET + cell) * blockSize + curveIndex;
          final int valueAsUint32 = _curvesAsUint32[cellIndex];
          if (valueAsUint32 == 0xFFFFFFFF) {
            _cellsAsUint32[cell] = valueAsUint32;
            continue;
          }
          final double valueAsFloat32 = _curvesAsFloat32[cellIndex];
          if (!valueAsFloat32.isNaN) {
            _cellsAsFloat32[cell] = valueAsFloat32;
            continue;
          }
          final int arg = valueAsUint32 & 0x0000FFFF;
          final int mode = valueAsUint32 >> 16;
          switch (mode) {
            case 0xFFD0:
              isStatic = false;
              _cellsAsFloat32[cell] = arg < _PARAM_COUNT ? _parametersAsFloat32[arg] : 0.0;
              break;
            case 0xFFE0:
              isStatic = false;
              _cellsAsFloat32[cell] = arg < _EXPR_COUNT ? _resolvedExpressionsAsFloat32[arg] : 0.0;
              break;
            default:
              _cellsAsFloat32[cell] = valueAsFloat32;
          }
          isStatic = false;
        }
        if (_cellsAsUint32[6] == 0xFFFFFFFF && !_cellsAsFloat32[5].isNaN) {
          // cubic bezier
          _path.cubicTo(
            _cellsAsFloat32[2], _cellsAsFloat32[3],
            _cellsAsFloat32[4], _cellsAsFloat32[5],
            _cellsAsFloat32[0], _cellsAsFloat32[1],
          );
        } else if (_cellsAsUint32[5] == 0xFFFFFFFF) {
          // rational quadratic bezier
          _path.conicTo(
            _cellsAsFloat32[2], _cellsAsFloat32[3],
            _cellsAsFloat32[0], _cellsAsFloat32[1],
            _cellsAsFloat32[4],
          );
        }
      }
      if (isStatic && matrixIndex < _MATRIX_COUNT)
        isStatic = _staticMatrices[matrixIndex];
      target.addPath(_path, ui.Offset.zero, matrix4: matrixIndex < _MATRIX_COUNT ? _resolvedMatrices[matrixIndex].storage : _identityMatrix.storage);
    }
    _path.reset();
    return isStatic;
  }

  void _resolvePaint(int index, int operator, int color) {
    assert(!_staticResolvedPaints[index]);
    if (operator == 0xFFFFFFFF) {
      _resolvedPaints[index].color = _createColor(color);
      _staticResolvedPaints[index] = true;
      return;
    }
    final int arg = operator & 0x0000FFFF;
    final int mode = operator >> 16;
    switch (mode) {
      case 0xFFD0:
        _resolvedPaints[index].color = arg < _PARAM_COUNT ? _createColor(_parametersAsUint32[arg]) : const ui.Color(0x00000000);
        return;
      case 0xFFE0:
        _resolvedPaints[index].color = arg < _EXPR_COUNT ? _createColor(_resolvedExpressionsAsUint32[arg]) : const ui.Color(0x00000000);
        return;
      case 0xFFF0:
        if (arg < _PAINT_COUNT) {
          _resolvedPaints[index] = _paints[arg];
          break;
        }
        continue fail;
      fail: default:
        _resolvedPaints[index].color = const ui.Color(0x00000000);
    }
    _staticResolvedPaints[index] = true;
  }

  void paint(ui.Canvas canvas, ui.Rect rect) {
    if (_dirty)
      _recompute();
    assert(_paths.length == _resolvedPaints.length);
    canvas.save();
    canvas.scale(rect.width / width, rect.height / height);
    canvas.translate(rect.left, rect.top);
    for (int index = 0; index < _paths.length; index += 1) {
      canvas.drawPath(_paths[index], _resolvedPaints[index]);
    }
    canvas.restore();
  }

  static ui.Color _createColor(int rgba) {
    return ui.Color((rgba >> 8) + ((rgba & 0xFF) << 24));
  }
}

class BoolList {
  factory BoolList.filled(int count, bool initialValue) { // ignore: avoid_positional_boolean_parameters
    final int bits = _roundUp(count, 32);
    final BoolList result = BoolList._(Uint32List(bits));
    if (initialValue)
      result._storage.fillRange(0, result._storage.length, 0xFFFFFFFF);
    return result;
  }

  BoolList._(this._storage);

  final Uint32List _storage;

  bool operator [](int index) {
    assert(RangeError.checkValidIndex(index, this, 'index', _storage.length * 32) == index);
    return (_storage[index ~/ 32] & (0x1 << (index % 32))) > 0;
  }

  void operator []=(int index, bool value) {
    assert(RangeError.checkValidIndex(index, this, 'index', _storage.length * 32) == index);
    if (value) {
      _storage[index ~/ 32] = _storage[index ~/ 32] | (0x1 << (index % 32));
    } else {
      _storage[index ~/ 32] = _storage[index ~/ 32] & ~(0x1 << (index % 32));
    }
  }

  static int _roundUp(int value, int modulus) {
    // The following bit magic checks that modulus is a power of two.
    assert(modulus > 0 && ((modulus & (~modulus + 1)) == modulus), '$modulus is not a power of two');
    // The following bit magic rounds up to the nearest multiple of modulus.
    return (value + modulus - 1) & ~(modulus - 1);
  }

  @override
  String toString() {
    final StringBuffer result = StringBuffer()
      ..write('[');
    for (int index = 0; index < _storage.length; index += 1)
      result.write(this[index] ? '#' : '.');
    result.write(']');
    return '$result';
  }
}
