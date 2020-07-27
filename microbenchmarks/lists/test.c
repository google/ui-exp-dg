// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <time.h>
#include <stdio.h>

const int size = 100000;
int main() {
  clock_t watch = clock();
  int index = 0;
  while (index < 10000) {
    int foo[size];
    for (int subindex = 0; subindex < size; subindex += 1)
      foo[subindex] = 1;
    index += foo[12487];
  }
  printf("%.2fs\n", (double)(clock() - watch) / 1000000);
}
