// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const size = 100000;
void main() {
  final Stopwatch watch = Stopwatch()..start();
  int index = 0;
  while (index < 10000) {
    final List<int> foo = List.filled(size, 1);
    index += foo[12487];
  }
  print('${(watch.elapsedMicroseconds / 1000000).toStringAsFixed(2)}s');
}
