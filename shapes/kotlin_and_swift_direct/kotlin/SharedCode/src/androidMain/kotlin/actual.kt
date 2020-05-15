// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.jetbrains.handson.mpp.mobile

actual class Serialized actual constructor(root: Serializable) {
    val root: Serializable = root
    actual fun release() {}
}
