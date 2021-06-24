import 'dart:convert';
import 'dart:io';

import 'package:wvg_handcrafter/wvg_handcrafter.dart';

void main() async {
  stdout.add(WvgTxt.assemble(await stdin.transform(utf8.decoder).join('')));
}
