import 'dart:io';
import 'dart:typed_data';

void main() async {
  Uint8List bytes = Uint8List.fromList(await stdin.expand((List<int> bytes) => bytes).toList());
  Uint32List words = bytes.buffer.asUint32List();
  Map<int, String> blockNames = <int, String>{};
  Map<int, String> blockComments = <int, String>{};
  if (words.length >= 64 && words[0] == 0x0a475657) {
    blockNames[0] = 'HEADER';
    int blockType = 0;
    int block = 1;
    for (int word in words.skip(1).take(63)) {
      if (word > 0) {
        for (int index = 0; index < word; index += 1) {
          final String name;
          String? comment;
          switch (blockType) {
            case 0:
              name = 'MDATA';
              break;
            case 7:
              name = 'PARAM';
              break;
            case 15:
              name = 'EXPR';
              comment = '#${index.toRadixString(16)}';
              break;
            case 23:
              name = 'MATRIX';
              comment = '${(index*4).toRadixString(16)}-${((index+1)*4-1).toRadixString(16)}';
              break;
            case 31:
              name = 'CURVE';
              break;
            case 35:
              name = 'SHAPE';
              comment = '${(index*16).toRadixString(16)}-${((index+1)*16-1).toRadixString(16)}';
              break;
            case 43:
              name = 'GRAD';
              if (index % 2 == 0)
                comment = '#${(index ~/ 2).toRadixString(16)}';
              break;
            case 47:
              name = 'PAINT';
              comment = '#${index.toRadixString(16)}';
              break;
            case 55:
              name = 'COMP';
              comment = '#${index.toRadixString(16)}';
              break;
            default:
              name = '($blockType)';
              break;
          }
          blockNames[block] = name;
          if (comment != null)
            blockComments[block] = comment;
          block += 1;
        }
      }
      blockType += 1;
    }
  }
  int count = 0;
  int block = 0;
  for (int word in words) {
    if (count % 64 == 0) {
      if (count > 0) {
        stdout.writeln();
        block += 1;
      }
      stdout.write('${(count ~/ 64).toString().padLeft(5, ' ')}:');
    } else if (count % 64 == 16) {
      stdout.writeln();
      if (blockNames.containsKey(block)) {
        stdout.write(blockNames[block]!.padLeft(6));
      } else {
        stdout.write('      ');
      }
    } else if (count % 64 == 32) {
      stdout.writeln();
      if (blockComments.containsKey(block)) {
        stdout.write(blockComments[block]!.padLeft(6));
      } else {
        stdout.write('      ');
      }
    } else if (count % 16 == 0) {
      stdout.writeln();
      stdout.write('      ');
    }
    stdout.write(' ');
    stdout.write(word.toRadixString(16).padLeft(8, '0'));
    count += 1;
  }
  stdout.writeln();
  stdout.writeln('Total length: ${count ~/ 64} blocks, $count words, ${count * 4} bytes.');
}
