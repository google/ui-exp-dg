// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.jetbrains.handson.mpp.mobile

import kotlinx.cinterop.*

actual class Serialized actual constructor(root: Serializable) {
    private var data: Pinned<UIntArray>
    val length: Int

    init {
        var buffer: UIntArray = UIntArray((5 * 1024 * 1024) / 4)
        val writer: BufferWriter = BufferWriter(buffer)
        root.write(writer)
        data = buffer.pin()
        length = writer.currentSize
        pinnedCount += 1
    }

    val buffer: CPointer<UIntVar> get() = data.addressOf(0)

    actual fun release() {
      data.unpin()
      pinnedCount -= 1
    }

    @ThreadLocal
    companion object {
      var pinnedCount = 0
    }
}
