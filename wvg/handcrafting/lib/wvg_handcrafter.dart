library wvg_handcrafter;

import 'dart:typed_data';

import 'package:meta/meta.dart';

enum _TokenizerMode { top, identifier, reference, numeric, path, pathNumeric, pathNumericDecimal }

enum _PathCommand { M, m, L, l, H, h, V, v, C, c, S, s, Q, q, T, t, A, a, Z, z }

abstract class WvgTxt {
  WvgTxt._();

  static Uint8List assemble(String file) {
    final Map<String, int> _labels = <String, int>{};
    final Map<int, int> _sizes = <int, int>{};
    Uint8List _bytes = _serialize(
      _labels,
      _sizes,
      _expand(
        _labels,
        _sizes,
        _map(
          _parse(
            _tokenize(file).toList(),
          ).toList(),
        ),
      ).toList(),
    ).buffer.asUint8List();
    assert(_bytes[0] == 0x57);
    assert(_bytes[1] == 0x56);
    assert(_bytes[2] == 0x47);
    assert(_bytes[3] == 0x0A);
    assert(_bytes.length % (blockSize * 4) == 0);
    assert(_bytes.length ~/ (blockSize * 4) == 1 + _sizes.values.reduce((int value, int element) => value + element));
    return _bytes;
  }

  static const int METADATA_BLOCKS = 0;
  static const int PARAM_BLOCKS = 7;
  static const int EXPR_BLOCKS = 15;
  static const int MATRIX_BLOCKS = 23;
  static const int CURVE_BLOCKS = 31;
  static const int SHAPE_BLOCKS = 35;
  static const int GRADIENT_BLOCKS = 43;
  static const int PAINT_BLOCKS = 47;
  static const int COMP_BLOCKS = 55;

  static const int blockSize = 64;
  static const int matrixSize = 16;
  static const int shapeSize = 4;
  static const int maxParameters = 65536;
  static const int maxExpressions = 65536;
  static const int maxMatrices = 4294967296;
  static const int maxShapes = 4294967296;
  static const int maxGradients = 2147483648;
  static const int maxPaints = 65536;

  static ByteData _serialize(Map<String, int> _labels, Map<int, int> _sizes, List<_Word> words) {
    assert(words.length % blockSize == 0);
    assert(words.length ~/ blockSize == _sizes.values.reduce((int value, int element) => value + element));
    ByteData result = ByteData(blockSize * 4 + words.length * 4);
    result.setUint32(0, 0x0A475657, Endian.little);
    for (int index = 1; index < blockSize; index += 1)
      result.setUint32(index * 4, _sizes[index - 1]!, Endian.little);
    int index = blockSize * 4;
    for (_Word word in words) {
      result.setUint32(index, word.resolve(_labels), Endian.little);
      index += 4;
    }
    return result;
  }

  static int roundUp(int value, int modulus) {
    // The following bit magic checks that modulus is a power of two.
    assert(modulus > 0 && ((modulus & (~modulus + 1)) == modulus), '$modulus is not a power of two');
    // The following bit magic rounds up to the nearest multiple of modulus.
    return (value + modulus - 1) & ~(modulus - 1);
  }

  static Iterable<_Word> _expand(Map<String, int> _labels, Map<int, int> _sizes, Map<int, List<_Block>> blocks) sync* {
    int blockTypeIndex = 0;
    Iterable<_Word> emitRawBlocks({ required int until }) sync* {
      assert(blockTypeIndex < until);
      while (blockTypeIndex < until) {
        assert(!_sizes.containsKey(blockTypeIndex));
        int count = 0;
        if (blocks.containsKey(blockTypeIndex)) {
          assert(blocks[blockTypeIndex]!.every((_Block block) => block is _RawBlock), 'blocks $blockTypeIndex: ${blocks[blockTypeIndex]}');
          for (_Block block in blocks[blockTypeIndex]!) {
            block as _RawBlock;
            assert(block.data.isNotEmpty);
            if (block.hasLabel) {
              _labels[block.label!] = count;
            }
            final List<_Word> data = block.filled(blockSize, const _LiteralWord(0)).toList();
            assert(data.length % blockSize == 0);
            yield* data;
            count += data.length ~/ blockSize;
          }
        }
        _sizes[blockTypeIndex] = count;
        blockTypeIndex += 1;
      }
    }

    // METADATA AND RAW BLOCKS...
    yield* emitRawBlocks(until: PARAM_BLOCKS);

    // PARAMETERS
    if (blocks.containsKey(PARAM_BLOCKS)) {
      int count = 0;
      for (_Block block in blocks[PARAM_BLOCKS]!) {
        if (block is _PackedBlock) {
          if (block.hasLabel && count < maxParameters) {
            _labels[block.label!] = 0xFFD00000 + count;
          }
          yield* block.data;
          count += block.data.length;
        } else {
          assert(block is _RawBlock);
          block as _RawBlock;
          // align on a block boundary
          int previousCount = count;
          count = roundUp(count, blockSize);
          if (count > previousCount)
            yield* List<_Word>.filled(count - previousCount, _LiteralWord.zero);
          // insert raw data from block
          if (block.hasLabel && count < maxParameters) {
            _labels[block.label!] = 0xFFD00000 + count;
          }
          // align on a block boundary
          int filledBlockSize = roundUp(block.data.length, blockSize);
          yield* block.filled(blockSize, _LiteralWord.zero);
          count += filledBlockSize;
        }
      }
      // align on a block boundary
      int padding = roundUp(count, blockSize) - count;
      if (padding > 0) {
        yield* List<_Word>.filled(padding, _LiteralWord.zero);
        count += padding;
      }
      assert(count % blockSize == 0, '$count vs $blockSize');
      _sizes[PARAM_BLOCKS] = count ~/ blockSize;
    } else {
      _sizes[PARAM_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: EXPR_BLOCKS);

    // EXPRESSIONS
    if (blocks.containsKey(EXPR_BLOCKS)) {
      int count = 0;
      for (_Block block in blocks[EXPR_BLOCKS]!) {
        block as _RawBlock;
        if (block.hasLabel && count < maxExpressions) {
          _labels[block.label!] = 0xFFE00000 + count;
        }
        yield* block.filled(blockSize, _LiteralWord.NaN);
        count += 1;
      }
      _sizes[EXPR_BLOCKS] = count;
    } else {
      _sizes[EXPR_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: MATRIX_BLOCKS);

    // MATRICES
    if (blocks.containsKey(MATRIX_BLOCKS)) {
      int count = 0;
      for (_Block block in blocks[MATRIX_BLOCKS]!) {
        if (block is _PackedBlock) {
          if (block.hasLabel && count < maxMatrices) {
            _labels[block.label!] = count;
          }
          yield* block.filled(matrixSize, _LiteralWord.NaN);
          count += 1;
        } else {
          block as _RawBlock;
          // align on a block boundary
          int previousCount = count;
          count = roundUp(count, blockSize ~/ matrixSize);
          if (count > previousCount)
            yield* List<_Word>.filled((count - previousCount) * matrixSize, _LiteralWord.zero);
          // insert raw data from block
          if (block.hasLabel && count < maxMatrices) {
            _labels[block.label!] = count;
          }
          // align on a block boundary
          int filledBlockSize = roundUp(block.data.length, blockSize);
          yield* block.filled(blockSize, _LiteralWord.zero);
          count += filledBlockSize ~/ matrixSize;
        }
      }
      // align on a block boundary
      int padding = roundUp(count, blockSize ~/ matrixSize) - count;
      yield* List<_Word>.filled(padding * matrixSize, _LiteralWord.zero);
      count += padding;
      assert((count * matrixSize) % blockSize == 0);
      _sizes[MATRIX_BLOCKS] = count ~/ (blockSize ~/ matrixSize);
    } else {
      _sizes[MATRIX_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: CURVE_BLOCKS);

    // CURVES
    if (blocks.containsKey(CURVE_BLOCKS)) {
      List<_CurveBlock> curves = <_CurveBlock>[];
      List<_Word> blockContents = <_Word>[];
      void compileCurves() {
        if (curves.isEmpty)
          return;
        int groupSize = 0;
        for (_CurveBlock curve in curves) {
          if (curve.data.length > groupSize)
            groupSize = curve.data.length;
        }
        int index = 0;
        for (_CurveBlock curve in curves) {
          if (curve.hasLabel) {
            assert(groupSize > 0);
            _labels[curve.label!] = (groupSize << 40) + ((index % blockSize) << 32) + (blockContents.length ~/ 64);
          }
          index += 1;
        }
        assert(blockContents.length % blockSize == 0);
        final int wordCount = roundUp(curves.length, blockSize);
        List<List<_Word>> unstripedData = List<List<_Word>>.generate(groupSize, (int coordinateIndex) {
          return List<_Word>.generate(wordCount, (int curveIndex) {
            if (curveIndex >= curves.length)
              return _LiteralWord.NaN;
            if (coordinateIndex < curves[curveIndex].data.length)
              return curves[curveIndex].data[coordinateIndex];
            return _LiteralWord.NaN;
          });
        });
        assert(wordCount % blockSize == 0);
        int groupCount = wordCount ~/ 64;
        for (int group = 0; group < groupCount; group += 1) {
          for (int coordinateIndex = 0; coordinateIndex < groupSize; coordinateIndex += 1) {
            blockContents.addAll(unstripedData[coordinateIndex].sublist(group * blockSize, (group + 1) * blockSize));
          }
        }
      }
      for (_Block block in blocks[CURVE_BLOCKS]!) {
        if (block is _CurveBlock) {
          curves.add(block);
        } else {
          assert(block is _RawBlock);
          block as _RawBlock;
          compileCurves();
          if (block.hasLabel && blockContents.length < blockSize) {
            assert(curves.isEmpty);
            assert(blockContents.length % blockSize == 0);
            _labels[block.label!] = blockContents.length ~/ blockSize;
          }
          blockContents.addAll(block.filled(blockSize, _LiteralWord.NaN));
        }
      }
      compileCurves();
      yield* blockContents;
      assert(blockContents.length % blockSize == 0);
      _sizes[CURVE_BLOCKS] = blockContents.length ~/ blockSize;
    } else {
      _sizes[CURVE_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: SHAPE_BLOCKS);

    // SHAPES
    if (blocks.containsKey(SHAPE_BLOCKS)) {
      int count = 0;
      for (_Block block in blocks[SHAPE_BLOCKS]!) {
        if (block is _ShapeBlock) {
          if (block.hasLabel && count < maxShapes) {
            _labels[block.label!] = count;
          }
          yield* block.resolve(_labels);
          count += 1;
        } else {
          block as _RawBlock;
          // align on a block boundary
          int previousCount = count;
          count = roundUp(count, blockSize ~/ shapeSize);
          if (count > previousCount)
            yield* List<_Word>.filled((count - previousCount) * shapeSize, _LiteralWord.zero);
          // insert raw data from block
          if (block.hasLabel && count < maxShapes) {
            _labels[block.label!] = count;
          }
          // align on a block boundary
          int filledBlockSize = roundUp(block.data.length, blockSize);
          yield* block.filled(blockSize, _LiteralWord.zero);
          count += filledBlockSize ~/ shapeSize;
        }
      }
      // align on a block boundary
      int padding = roundUp(count, blockSize ~/ shapeSize) - count;
      yield* List<_Word>.filled(padding * shapeSize, _LiteralWord.zero);
      count += padding;
      assert((count * shapeSize) % blockSize == 0);
      _sizes[SHAPE_BLOCKS] = count ~/ (blockSize ~/ shapeSize);
    } else {
      _sizes[SHAPE_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: GRADIENT_BLOCKS);

    // GRADIENTS
    if (blocks.containsKey(GRADIENT_BLOCKS)) {
      int count = 0;
      for (_Block block in blocks[GRADIENT_BLOCKS]!) {
        if (block is _GradientStopBlock) {
          assert(count % 2 == 0);
          if (block.hasLabel && count < maxGradients) {
            _labels[block.label!] = count ~/ 2;
          }
          assert(block.data.length <= blockSize);
          yield* block.autofilled();
          count += 1;
        } else if (block is _GradientColorBlock) {
          assert(count % 2 == 1);
          assert(!block.hasLabel);
          assert(block.data.length <= blockSize);
          yield* block.autofilled();
          count += 1;
        } else {
          block as _RawBlock;
          // align on a block-pair boundary
          if (count % 2 == 1) {
            yield* List<_Word>.filled(blockSize, _LiteralWord.zero);
            count += 1;
          }
          assert(count % 2 == 0);
          // insert raw data from block
          if (block.hasLabel && count < maxGradients) {
            _labels[block.label!] = count ~/ 2;
          }
          List<_Word> values = block.filled(blockSize * 2, _LiteralWord.zero).toList();
          assert(values.length % (blockSize * 2) == 0);
          yield* values;
          count += values.length ~/ blockSize;
        }
      }
      _sizes[GRADIENT_BLOCKS] = count;
    } else {
      _sizes[GRADIENT_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: PAINT_BLOCKS);

    // PAINTS
    if (blocks.containsKey(PAINT_BLOCKS)) {
      int count = 0;
      for (_Block block in blocks[PAINT_BLOCKS]!) {
        block as _RawBlock;
        if (block.hasLabel && count < maxPaints) {
          _labels[block.label!] = 0xFFF00000 + count;
        }
        yield* block.filled(blockSize, _LiteralWord.zero);
        count += 1;
      }
      _sizes[PAINT_BLOCKS] = count;
    } else {
      _sizes[PAINT_BLOCKS] = 0;
    }
    blockTypeIndex += 1;

    // RAW BLOCKS...
    yield* emitRawBlocks(until: COMP_BLOCKS);

    // COMPOSITIONS
    // can be done as a raw block

    // RAW BLOCKS...
    yield* emitRawBlocks(until: blockSize - 1);
  }

  static Map<int, List<_Block>> _map(List<_Block> blocks) {
    Map<int, List<_Block>> result = <int, List<_Block>>{};
    for (_Block block in blocks) {
      result.putIfAbsent(block.type, () => <_Block>[]).add(block);
    }
    return result;
  }

  static Iterable<_Block> _parse(List<_Token> tokens) sync* {
    int index = 0;

    bool peekToken<T extends _Token>() {
      _Token result = tokens[index];
      return result is T;
    }

    T getToken<T extends _Token>() {
      _Token result = tokens[index];
      if (result is! T) {
        throw ParseError('Unexpected "$result"', result.line, result.column);
      }
      index += 1;
      return result;
    }

    Iterable<_Word> getWordList({ int? max }) sync* {
      assert(max == null || max > 1);
      int count = 0;
      do {
        _WordToken token = getToken<_WordToken>();
        count += 1;
        if (max != null && count > max) {
          throw ParseError('Unexpected word; expected no more than $max words', token.line, token.column);
        }
        yield token.asWord();
      } while (peekToken<_WordToken>());
    }

    Iterable<_Block> _decodePath(String? label, String reference) sync* {
      double x = 0.0;
      double y = 0.0;
      double originX = 0.0;
      double originY = 0.0;
      _PathCommand lastCommand = _PathCommand.z;
      bool lastCommandWasCubic() => lastCommand == _PathCommand.C || lastCommand == _PathCommand.c || lastCommand == _PathCommand.S || lastCommand == _PathCommand.s;
      bool lastCommandWasQuadratic() => lastCommand == _PathCommand.Q || lastCommand == _PathCommand.q || lastCommand == _PathCommand.T || lastCommand == _PathCommand.t;
      double lastControlX = 0.0;
      double lastControlY = 0.0;
      late _PathCommandToken token;

      void _moveTo(double fromX, double fromY) {
        originX = fromX + getToken<_FloatToken>().value;
        originY = fromY + getToken<_FloatToken>().value;
      }

      List<_Word> _computeQuadraticBezier(double x1, double y1, double x2, double y2, double w) {
        x = x2;
        y = y2;
        lastControlX = x1;
        lastControlY = y1;
        return <_Word>[
          _LiteralWord.fromDouble(x2),
          _LiteralWord.fromDouble(y2),
          _LiteralWord.fromDouble(x1),
          _LiteralWord.fromDouble(y1),
          _LiteralWord.fromDouble(w),
        ];
      }

      List<_Word> _arcTo(double fromX, double fromY) {
        throw UnimplementedError();
      }

      List<_Word> _computeCubicBezier(double x1, double y1, double x2, double y2, double x3, double y3) {
        x = x3;
        y = y3;
        lastControlX = x2;
        lastControlY = y2;
        return <_Word>[
          _LiteralWord.fromDouble(x3),
          _LiteralWord.fromDouble(y3),
          _LiteralWord.fromDouble(x1),
          _LiteralWord.fromDouble(y1),
          _LiteralWord.fromDouble(x2),
          _LiteralWord.fromDouble(y2),
        ];
      }

      List<_Word> _computeLineTo(double toX, double toY) {
        return _computeCubicBezier(x, y, toX, toY, toX, toY);
      }

      List<_Word> _lineTo(double fromX, double fromY) {
        return _computeLineTo(fromX + getToken<_FloatToken>().value, fromY + getToken<_FloatToken>().value);
      }

      List<_Word> _horizTo(double fromX, double fromY) {
        return _computeLineTo(fromX + getToken<_FloatToken>().value, fromY);
      }

      List<_Word> _vertTo(double fromX, double fromY) {
        return _computeLineTo(fromX, fromY + getToken<_FloatToken>().value);
      }

      List<_Word> _cubicTo(double fromX, double fromY) {
        return _computeCubicBezier(
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
        );
      }

      List<_Word> _smoothCubicTo(double fromX, double fromY) {
        if (!lastCommandWasCubic()) {
          lastControlX = x;
          lastControlY = x;
        }
        return _computeCubicBezier(
          2.0 * x - lastControlX,
          2.0 * y - lastControlY,
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
        );
      }

      double _maybeGetWeight() {
        if (peekToken<_AsteriskToken>()) {
          getToken<_AsteriskToken>();
          return getToken<_FloatToken>().value;
        }
        return 1.0;
      }
      
      List<_Word> _quadraticTo(double fromX, double fromY) {
        return _computeQuadraticBezier(
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
          _maybeGetWeight(),
        );
      }

      List<_Word> _smoothQuadraticTo(double fromX, double fromY) {
        if (!lastCommandWasQuadratic()) {
          lastControlX = x;
          lastControlY = x;
        }
        return _computeQuadraticBezier(
          2.0 * x - lastControlX,
          2.0 * y - lastControlY,
          fromX + getToken<_FloatToken>().value,
          fromY + getToken<_FloatToken>().value,
          _maybeGetWeight(),
        );
      }

      List<List<_Word>> curves = <List<_Word>>[];
      int shapeCount = 0;

      Iterable<_Block> _flushShape () sync* {
        assert(curves.isNotEmpty);
        String subref = '$reference:$shapeCount';
        bool first = true;
        for (List<_Word> curve in curves) {
          yield _CurveBlock(CURVE_BLOCKS, first ? '$subref:curve' : null, curve);
          first = false;
        }
        yield _ShapeBlock(SHAPE_BLOCKS, (shapeCount == 0 && label != null) ? label : '$subref:shape', _ReferenceWord(_ReferenceToken('$subref:curve', 0, 0)), curves.length);
        yield(_PackedBlock(MATRIX_BLOCKS, (shapeCount == 0 && label != null) ? '$label:matrix' : '$subref:matrix', <_Word>[
          _LiteralWord.fromDouble(1.0),     _LiteralWord.fromDouble(0.0),     _LiteralWord.fromDouble(0.0), _LiteralWord.fromDouble(0.0),
          _LiteralWord.fromDouble(0.0),     _LiteralWord.fromDouble(1.0),     _LiteralWord.fromDouble(0.0), _LiteralWord.fromDouble(0.0),
          _LiteralWord.fromDouble(0.0),     _LiteralWord.fromDouble(0.0),     _LiteralWord.fromDouble(1.0), _LiteralWord.fromDouble(0.0),
          _LiteralWord.fromDouble(originX), _LiteralWord.fromDouble(originY), _LiteralWord.fromDouble(0.0), _LiteralWord.fromDouble(1.0),
        ]));
        curves.clear();
        shapeCount += 1;
        x = 0.0;
        y = 0.0;
      }

      do {
        if (peekToken<_PathCommandToken>())
          token = getToken<_PathCommandToken>();
        switch (token.command) {
          case _PathCommand.M:
            if (curves.isNotEmpty)
              yield* _flushShape();
            _moveTo(0.0, 0.0);
            break;
          case _PathCommand.m:
            if (curves.isNotEmpty)
              yield* _flushShape();
            _moveTo(originX, originY);
            break;
          case _PathCommand.A:
            curves.add(_arcTo(-originX, -originY));
            break;
          case _PathCommand.a:
            curves.add(_arcTo(x, y));
            break;
          case _PathCommand.L:
            curves.add(_lineTo(-originX, -originY));
            break;
          case _PathCommand.l:
            curves.add(_lineTo(x, y));
            break;
          case _PathCommand.H:
            curves.add(_horizTo(-originX, y));
            break;
          case _PathCommand.h:
            curves.add(_horizTo(x, y));
            break;
          case _PathCommand.V:
            curves.add(_vertTo(x, -originY));
            break;
          case _PathCommand.v:
            curves.add(_vertTo(x, y));
            break;
          case _PathCommand.C:
            curves.add(_cubicTo(-originX, -originY));
            break;
          case _PathCommand.c:
            curves.add(_cubicTo(x, y));
            break;
          case _PathCommand.S:
            curves.add(_smoothCubicTo(-originX, -originY));
            break;
          case _PathCommand.s:
            curves.add(_smoothCubicTo(x, y));
            break;
          case _PathCommand.Q:
            curves.add(_quadraticTo(-originX, -originY));
            break;
          case _PathCommand.q:
            curves.add(_quadraticTo(x, y));
            break;
          case _PathCommand.T:
            curves.add(_smoothQuadraticTo(-originX, -originY));
            break;
          case _PathCommand.t:
            curves.add(_smoothQuadraticTo(x, y));
            break;
          case _PathCommand.Z:
          case _PathCommand.z:
            if (curves.isNotEmpty)
              yield* _flushShape();
            break;
        }
        lastCommand = token.command;
      } while (peekToken<_PathCommandToken>() || peekToken<_FloatToken>());
      if (curves.isNotEmpty)
        yield* _flushShape();
    }

    Set<String> labels = <String>{};
    while (!peekToken<_EndOfFileToken>()) {
      String? label;
      _IdentifierToken ident = getToken<_IdentifierToken>();
      if (peekToken<_ColonToken>()) {
        label = ident.value;
        if (labels.contains(label)) {
          throw ParseError('Duplicate label "$label"', ident.line, ident.column);
        }
        labels.add(label);
        getToken<_ColonToken>();
        ident = getToken<_IdentifierToken>();
      }
      late int type;
      if (ident.value == 'raw') {
        _IntegerToken typeToken = getToken<_IntegerToken>();
        type = typeToken.value;
        if (type < 0 || type > blockSize - 2)
          throw ParseError('Invalid block type; expected identifier in range 0..${blockSize-2}', typeToken.line, typeToken.column);
      }
      getToken<_OpenBraceToken>();
      switch (ident.value) {
        case 'metadata':
          yield _RawBlock(METADATA_BLOCKS, label, getWordList().toList());
          break;
        case 'parameter':
          yield _PackedBlock(PARAM_BLOCKS, label, <_Word>[getToken<_WordToken>().asWord()]);
          break;
        case 'expression':
          yield _RawBlock(EXPR_BLOCKS, label, getWordList(max: blockSize).toList());
          break;
        case 'matrix':
          yield _PackedBlock(MATRIX_BLOCKS, label, getWordList(max: matrixSize).toList());
          break;
        case 'rawcurve':
          yield _CurveBlock(CURVE_BLOCKS, label, getWordList().toList());
          break;
        case 'rawshape':
          yield _ShapeBlock(SHAPE_BLOCKS, label, _ReferenceWord(getToken<_ReferenceToken>()), getToken<_IntegerToken>().value);
          break;
        case 'shape':
          final String reference = label ?? 'shape:${ident.line}:${ident.column}';
          if (peekToken<_PathCommandToken>()) {
            yield* _decodePath(label, reference);
          } else {
            final List<List<_Word>> curves = <List<_Word>>[];
            do {
              curves.add(getWordList(max: blockSize).toList());
              if (peekToken<_SemicolonToken>()) {
                getToken<_SemicolonToken>();
              }
            } while (!peekToken<_CloseBraceToken>());
            bool useLabel = true;
            for (List<_Word> curve in curves) {
              yield _CurveBlock(CURVE_BLOCKS, useLabel ? '$reference:curve' : null, curve);
              useLabel = false;
            }
            yield _ShapeBlock(SHAPE_BLOCKS, label, _ReferenceWord(_ReferenceToken('$reference:curve', 0, 0)), curves.length);
          }
          break;
        case 'gradient':
          List<_Word> stops = getWordList().toList();
          getToken<_SemicolonToken>();
          List<_Word> colors = getWordList().toList();
          for (int index = 0; index < colors.length; index += 1) {
            if (colors[index] is _LiteralWord) {
              String color = '${label ?? "gradient:${ident.line}:${ident.column}"}:color:$index';
              yield _PackedBlock(PARAM_BLOCKS, color, <_Word>[colors[index]]);
              colors[index] = _ReferenceWord(_ReferenceToken(color, 0, 0));
            }
          }
          yield _GradientStopBlock(GRADIENT_BLOCKS, label, stops);
          yield _GradientColorBlock(GRADIENT_BLOCKS, null, colors);
          break;
        case 'paint':
          yield _RawBlock(PAINT_BLOCKS, label, getWordList().toList());
          break;
        case 'draw':
           yield _RawBlock(COMP_BLOCKS, label, getWordList().toList());
          break;
        case 'raw':
           yield _RawBlock(type, label, getWordList().toList());
          break;
        default:
          throw ParseError('unrecognized block name "${ident.value}"', ident.line, ident.column);
      }
      getToken<_CloseBraceToken>();
    }
  }

  static Iterable<_Token> _tokenize(String file) sync* {
    int line = 1;
    int column = 0;
    final List<int> buffer = <int>[];
    _TokenizerMode mode = _TokenizerMode.top;
    for (int rune in file.runes.followedBy(<int>[-1])) {
      column += 1;
      switch (mode) {
        top: case _TokenizerMode.top:
          assert(buffer.isEmpty);
          if ((rune >= 0x41 && rune <= 0x5A) || // A-Z
              (rune >= 0x61 && rune <= 0x7A) || // a-z
              (rune == 0x5F)) { // _
            mode = _TokenizerMode.identifier;
            continue identifier;
          }
          if ((rune >= 0x30 && rune <= 0x39) || // 0-9
              (rune == 0x2D)) { // -
            mode = _TokenizerMode.numeric;
            continue numeric;
          }
          switch (rune) {
            case -1:
              yield _EndOfFileToken(line, column);
              return;
            case 0x0A:
              line += 1;
              column = 1;
              break;
            case 0x20: // space
              break;
            case 0x22: // "
              mode = _TokenizerMode.path;
              break;
            case 0x2A: // *
              yield _AsteriskToken(line, column);
              break;
            case 0x2B: // +
              yield _PlusToken(line, column);
              break;
            case 0x2D: // -
              yield _HyphenToken(line, column);
              break;
            case 0x2F: // /
              yield _SlashToken(line, column);
              break;
            case 0x3A: // :
              yield _ColonToken(line, column);
              break;
            case 0x3B: // ;
              yield _SemicolonToken(line, column);
              break;
            case 0x40: // @
              mode = _TokenizerMode.reference;
              break;
            case 0x7B: // {
              yield _OpenBraceToken(line, column);
              break;
            case 0x7D: // }
              yield _CloseBraceToken(line, column);
              break;
            default:
              throw ParseError('Unexpected character "${String.fromCharCode(rune)}" (U+${rune.toRadixString(16).padLeft(4, "0")})', line, column);
          }
          break;

        case _TokenizerMode.reference:
        identifier: case _TokenizerMode.identifier:
          if ((rune >= 0x30 && rune <= 0x39) || // 0-9
              (rune >= 0x41 && rune <= 0x5A) || // A-Z
              (rune >= 0x61 && rune <= 0x7A) || // a-z
              (rune == 0x5F) || // _
              (rune == 0x2D) ||
              (mode == _TokenizerMode.reference && rune == 0x3A)) { // :
            buffer.add(rune);
          } else {
            if (mode == _TokenizerMode.reference) {
              if (buffer.isEmpty) {
                throw ParseError('Unexpected identifier after @', line, column);
              }
              yield _ReferenceToken(String.fromCharCodes(buffer), line, column);
            } else {
              assert(buffer.isNotEmpty);
              yield _IdentifierToken(String.fromCharCodes(buffer), line, column);
            }
            buffer.clear();
            mode = _TokenizerMode.top;
            continue top;
          }
          break;

        numeric: case _TokenizerMode.numeric:
          if ((rune >= 0x30 && rune <= 0x39) || // 0-9
              (rune >= 0x41 && rune <= 0x46) || // A-F (hex), E (float)
              (rune >= 0x61 && rune <= 0x66) || // a-f (hex), e (float)
              (rune == 0x58) || (rune == 0x78) || // X, x
              (rune == 0x2D) || // -
              (rune == 0x2E)) { // .
            buffer.add(rune);
          } else {
            String value = String.fromCharCodes(buffer);
            int? integer = int.tryParse(value);
            if (integer != null) {
              yield _IntegerToken(integer, line, column);
            } else {
              double? float = double.tryParse(value);
              if (float != null) {
                yield _FloatToken(float, line, column);
              } else {
                throw ParseError('Could not parse "$value" as a number', line, column);
              }
            }
            buffer.clear();
            mode = _TokenizerMode.top;
            continue top;
          }
          break;

        path: case _TokenizerMode.path:
          assert(buffer.isEmpty);
          if ((rune >= 0x30 && rune <= 0x39) || // 0-9
              (rune == 0x2E)) { // .
            mode = _TokenizerMode.pathNumeric;
            continue pathNumeric;
          } else if ((rune == 0x2D) || // -
                     (rune == 0x2B)) { // +
            buffer.add(rune);
            mode = _TokenizerMode.pathNumeric;
          } else {
            switch (rune) {
              case 0x0020: // " "
                break;
              case 0x0022: // "
                mode = _TokenizerMode.top;
                break;
              case 0x002A: // *
                yield _AsteriskToken(line, column);
                break;
              case 0x002C: // ","
                break;
              case 0x004D: // U+004D LATIN CAPITAL LETTER M character
                yield _PathCommandToken(_PathCommand.M, line, column);
                break;
              case 0x006D: // U+006D LATIN SMALL LETTER M character
                yield _PathCommandToken(_PathCommand.m, line, column);
                break;
              case 0x004C: // U+004C LATIN CAPITAL LETTER L character
                yield _PathCommandToken(_PathCommand.L, line, column);
                break;
              case 0x006C: // U+006C LATIN SMALL LETTER L character
                yield _PathCommandToken(_PathCommand.l, line, column);
                break;
              case 0x0048: // U+0048 LATIN CAPITAL LETTER H character
                yield _PathCommandToken(_PathCommand.H, line, column);
                break;
              case 0x0068: // U+0068 LATIN SMALL LETTER H character
                yield _PathCommandToken(_PathCommand.h, line, column);
                break;
              case 0x0056: // U+0056 LATIN CAPITAL LETTER V character
                yield _PathCommandToken(_PathCommand.V, line, column);
                break;
              case 0x0076: // U+0076 LATIN SMALL LETTER V character
                yield _PathCommandToken(_PathCommand.v, line, column);
                break;
              case 0x0043: // U+0043 LATIN CAPITAL LETTER C character
                yield _PathCommandToken(_PathCommand.C, line, column);
                break;
              case 0x0063: // U+0063 LATIN SMALL LETTER C character
                yield _PathCommandToken(_PathCommand.c, line, column);
                break;
              case 0x0053: // U+0053 LATIN CAPITAL LETTER S character
                yield _PathCommandToken(_PathCommand.S, line, column);
                break;
              case 0x0073: // U+0073 LATIN SMALL LETTER S character
                yield _PathCommandToken(_PathCommand.s, line, column);
                break;
              case 0x0051: // U+0051 LATIN CAPITAL LETTER Q character
                yield _PathCommandToken(_PathCommand.Q, line, column);
                break;
              case 0x0071: // U+0071 LATIN SMALL LETTER Q character
                yield _PathCommandToken(_PathCommand.q, line, column);
                break;
              case 0x0054: // U+0054 LATIN CAPITAL LETTER T character
                yield _PathCommandToken(_PathCommand.T, line, column);
                break;
              case 0x0074: // U+0074 LATIN SMALL LETTER T character
                yield _PathCommandToken(_PathCommand.t, line, column);
                break;
              case 0x0041: // U+0041 LATIN CAPITAL LETTER A character
                yield _PathCommandToken(_PathCommand.A, line, column);
                break;
              case 0x0061: // U+0061 LATIN SMALL LETTER A character
                yield _PathCommandToken(_PathCommand.a, line, column);
                break;
              case 0x005A: // U+005A LATIN CAPITAL LETTER Z character
                yield _PathCommandToken(_PathCommand.Z, line, column);
                break;
              case 0x007A: // U+007A LATIN SMALL LETTER Z character
                yield _PathCommandToken(_PathCommand.z, line, column);
                break;
              case -1:
                throw ParseError('Unexpected end of file in SVG path string', line, column);
              default:
                throw ParseError('Unexpected character in SVG path string: "${String.fromCharCode(rune)}" (U+${rune.toRadixString(16).padLeft(4, "0")})', line, column);
            }
          }
          break;

        pathNumeric: case _TokenizerMode.pathNumeric:
          if (rune >= 0x30 && rune <= 0x39) { // 0-9
            buffer.add(rune);
          } else if (rune == 0x2E) { // .
            buffer.add(rune);
            mode = _TokenizerMode.pathNumericDecimal;
          } else {
            String value = String.fromCharCodes(buffer);
            double? float = double.tryParse(value);
            if (float != null) {
              yield _FloatToken(float, line, column);
            } else {
              throw ParseError('Could not parse "$value" as a number', line, column);
            }
            buffer.clear();
            mode = _TokenizerMode.path;
            continue path;
          }
          break;

        case _TokenizerMode.pathNumericDecimal:
          if (rune >= 0x30 && rune <= 0x39) { // 0-9
            buffer.add(rune);
          } else {
            String value = String.fromCharCodes(buffer);
            double? float = double.tryParse(value);
            if (float != null) {
              yield _FloatToken(float, line, column);
            } else {
              throw ParseError('Could not parse "$value" as a number', line, column);
            }
            buffer.clear();
            mode = _TokenizerMode.path;
            continue path;
          }
          break;

      }
    }
  }
}

@immutable
abstract class _Token {
  const _Token(this.line, this.column);
  final int line;
  final int column;
}

abstract class _WordToken extends _Token {
  const _WordToken(int line, int column) : super(line, column);
  _Word asWord();
}

class _IdentifierToken extends _WordToken {
  const _IdentifierToken(this.value, int line, int column) : super(line, column);
  final String value;

  @override
  _Word asWord() {
    switch (value) {
      case 'linear': return const _LiteralWord(0x10);
      case 'radial': return const _LiteralWord(0x14);
      case 'clamp': return const _LiteralWord(0x00);
      case 'repeated': return const _LiteralWord(0x01);
      case 'mirror': return const _LiteralWord(0x02);
      case 'decal': return const _LiteralWord(0x03);
      case 'negate-int': return const _LiteralWord(0x80000000);
      case 'negate': return const _LiteralWord(0x80010000);
      case 'as-int': return const _LiteralWord(0x80008000);
      case 'as-float': return const _LiteralWord(0x80018000);
      case 'duplicate': return const _LiteralWord(0x80020000);
      case 'add-int': return const _LiteralWord(0xC0000001);
      case 'subtract-int': return const _LiteralWord(0xC0000002);
      case 'multiply-int': return const _LiteralWord(0xC0000003);
      case 'divide-int': return const _LiteralWord(0xC0000004);
      case 'end': return const _LiteralWord(0xFFC00000);
      case 'color': return const _LiteralWord(0xFFFFFFFF);
      case 'identity': return const _LiteralWord(0xFFFFFFFF);
      default:
        throw ParseError('Unrecognized word literal "$value"', line, column);
    }
  }

  @override
  String toString() => value;
}

class _ReferenceToken extends _WordToken {
  const _ReferenceToken(this.value, int line, int column) : super(line, column);
  final String value;

  @override
  _Word asWord() => _ReferenceWord(this);

  @override
  String toString() => '@$value';
}

class _IntegerToken extends _WordToken {
  const _IntegerToken(this.value, int line, int column) : super(line, column);
  final int value;

  @override
  _Word asWord() => _LiteralWord(value);

  @override
  String toString() => '$value';
}

class _FloatToken extends _WordToken {
  const _FloatToken(this.value, int line, int column) : super(line, column);
  final double value;

  @override
  _Word asWord() {
    return _LiteralWord((ByteData(4)..setFloat32(0, value, Endian.host)).getUint32(0, Endian.host));
  }

  @override
  String toString() => '$value';
}

class _AsteriskToken extends _WordToken {
  const _AsteriskToken(int line, int column) : super(line, column);

  @override
  _Word asWord() => const _LiteralWord(0xC0010003);

  @override
  String toString() => '*';
}

class _PlusToken extends _WordToken {
  const _PlusToken(int line, int column) : super(line, column);

  @override
  _Word asWord() => const _LiteralWord(0xC0010001);

  @override
  String toString() => '+';
}

class _HyphenToken extends _WordToken {
  const _HyphenToken(int line, int column) : super(line, column);

  @override
  _Word asWord() => const _LiteralWord(0xC0010002);

  @override
  String toString() => '-';
}

class _SlashToken extends _WordToken {
  const _SlashToken(int line, int column) : super(line, column);

  @override
  _Word asWord() => const _LiteralWord(0xC0010004);

  @override
  String toString() => '/';
}

class _ColonToken extends _Token {
  const _ColonToken(int line, int column) : super(line, column);
  @override
  String toString() => ':';
}

class _SemicolonToken extends _Token {
  const _SemicolonToken(int line, int column) : super(line, column);
  @override
  String toString() => ';';
}

class _OpenBraceToken extends _Token {
  const _OpenBraceToken(int line, int column) : super(line, column);
  @override
  String toString() => '{';
}

class _CloseBraceToken extends _Token {
  const _CloseBraceToken(int line, int column) : super(line, column);
  @override
  String toString() => '}';
}

class _PathCommandToken extends _Token {
  const _PathCommandToken(this.command, int line, int column) : super(line, column);

  final _PathCommand command;

  @override
  String toString() => '$command';
}

class _EndOfFileToken extends _Token {
  const _EndOfFileToken(int line, int column) : super(line, column);
  @override
  String toString() => '<EOF>';
}

class ParseError extends FormatException {
  ParseError(String message, this.line, this.column) : super(message);
  final int line;
  final int column;
  @override
  String toString() => '$message at line $line column $column';
}

@immutable
abstract class _Word {
  const _Word();
  int resolve(Map<String, int> table);
}

class _LiteralWord extends _Word {
  const _LiteralWord(this.value);

  factory _LiteralWord.fromDouble(double value) {
    return _LiteralWord((ByteData(4)..setFloat32(0, value, Endian.host)).getUint32(0, Endian.host));
  }

  final int value;

  static const _LiteralWord NaN = _LiteralWord(0xFFFFFFFF);
  static const _LiteralWord zero = _LiteralWord(0);

  @override
  int resolve(Map<String, int> table) => value;

  @override
  String toString() {
    if (value > 0)
      return '0x${value.toRadixString(16).padLeft(8, "0")}';
    return '$value';
  }
}

class _ReferenceWord extends _Word {
  const _ReferenceWord(this.value);
  final _ReferenceToken value;

  @override
  int resolve(Map<String, int> table) {
    if (!table.containsKey(value.value))
      throw ParseError('Undeclared identifier "${value.value}"', value.line, value.column);
    return table[value.value]!;
  }

  @override
  String toString() => '@${value.value}';
}

@immutable
abstract class _Block {
  const _Block(this.type, this.label);
  final int type;
  final String? label;

  bool get hasLabel => label != null;

  @override
  String toString() {
    if (label != null) {
      return '$label: $type';
    }
    return '$type';
  }
}

class _DataBlock extends _Block {
  const _DataBlock(int type, String? label, this.data) : super(type, label);

  final List<_Word> data;

  Iterable<_Word> filled(int blockSize, _Word filler) sync* {
    int count = data.length;
    yield* data;
    if (count % blockSize > 0)
      yield* List<_Word>.filled(blockSize - count % blockSize, filler);
  }

  @override
  String toString() {
    return '${super.toString()} { $data }';
  }
}

class _RawBlock extends _DataBlock {
  const _RawBlock(int type, String? label, List<_Word> data) : super(type, label, data);
  // will get filled out to a multiple of blockSize
}

class _PackedBlock extends _DataBlock {
  const _PackedBlock(int type, String? label, List<_Word> data) : super(type, label, data);
  // will be packed with adjacent _PackedBlocks
}

class _GradientStopBlock extends _DataBlock {
  const _GradientStopBlock(int type, String? label, List<_Word> stops) : super(type, label, stops);
  Iterable<_Word> autofilled() => filled(WvgTxt.blockSize, _LiteralWord.NaN);
}

class _GradientColorBlock extends _DataBlock {
  const _GradientColorBlock(int type, String? label, List<_Word> colors) : super(type, label, colors);
  Iterable<_Word> autofilled() => filled(WvgTxt.blockSize, _LiteralWord.zero);
}

class _CurveBlock extends _Block {
  const _CurveBlock(int type, String? label, this.data) : super(type, label);
  final List<_Word> data;
  @override
  String toString() {
    return '${super.toString()} { $data }';
  }
}

class _ShapeBlock extends _Block {
  const _ShapeBlock(int type, String? label, this.reference, this.count) : super(type, label);
  final _ReferenceWord reference;
  final int count;

  List<_Word> resolve(Map<String, int> table) {
    if (!table.containsKey(reference.value.value))
      throw ParseError('Undeclared identifier "${reference.value.value}"', reference.value.line, reference.value.column);
    int combinedReference = table[reference.value.value]!;
    return <_Word>[
      _LiteralWord(combinedReference & 0xFFFFFFFF),
      _LiteralWord((combinedReference >> 32) & 0xFF),
      _LiteralWord(count),
      _LiteralWord((combinedReference >> 40) & 0xFF),
    ];
  }

  @override
  String toString() {
    return '${super.toString()} { @$reference $count }';
  }
}
