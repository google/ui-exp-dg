// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import kotlin.time.*

const val size = 100000

@kotlin.time.ExperimentalTime
fun main() {
  val watch: Duration = measureTime {
    var index: Int = 0
    while (index < 10000) {
      val foo: List<Int> = List(size) { 1 }
      index += foo[12487]
    }
  }
  println("${watch.inSeconds}s")
}
