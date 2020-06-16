// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.damowmow.shapes

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.*
import androidx.lifecycle.whenStarted
import androidx.ui.core.*
import androidx.ui.foundation.shape.corner.CircleShape
import androidx.ui.foundation.shape.corner.RoundedCornerShape
import androidx.ui.graphics.Color
import androidx.ui.material.Surface
import kotlin.random.Random
import kotlin.math.min
import androidx.ui.layout.Stack
import androidx.ui.layout.padding
import androidx.ui.layout.size
import androidx.ui.unit.dp

class MainActivity : AppCompatActivity() {
    private var lastFrameTime: Long = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            WithConstraints {
                Surface(
                    color = Color.Black
                ) {
                    Stack {
                        val angle = state { 0.0 }
                        val lifecycleOwner = LifecycleOwnerAmbient.current
                        launchInComposition {
                            lifecycleOwner.whenStarted {
                                while (true) {
                                    awaitFrameMillis { frameTime ->
                                        Log.d("Shapes", "total frame time = ${frameTime - lastFrameTime}ms")
                                        lastFrameTime = frameTime
                                        angle.value += 0.1
                                    }
                                }
                            }
                        }
                        val width = maxWidth.value.toDouble()
                        val height = maxHeight.value.toDouble()
                        val r = Random(0)
                        for (index in 0..10000) {
                            when (r.nextInt(2)) {
                                0 -> {
                                    val radius = r.nextDouble() * min(width, height) / 8
                                    val x = r.nextDouble() * (width - radius)
                                    val y = r.nextDouble() * (height - radius)
                                    val color = Color(0xFF000000 + r.nextLong(0x00FFFFFF))
                                    Surface(
                                        color = color,
                                        shape = CircleShape,
                                        modifier = Modifier.size(x.dp + radius.dp * 2.0f, y.dp + radius.dp * 2.0f).padding(x.dp, y.dp, 0.dp, 0.dp)
                                    ) { }
                                }
                                1 -> {
                                    val w = r.nextDouble() * width / 4.0
                                    val h = r.nextDouble() * height / 4.0
                                    val x = r.nextDouble() * (width - w)
                                    val y = r.nextDouble() * (height - h)
                                    val color = Color(r.nextLong(0xFFFFFFFF))
                                    Surface(
                                        color = color,
                                        shape = RoundedCornerShape(0),
                                        modifier = Modifier.size(x.dp + w.dp, y.dp + h.dp).padding(x.dp, y.dp, 0.dp, 0.dp).drawLayer(rotationZ = (angle.value * (r.nextDouble(2.0) - 1.0)).toFloat())
                                    ) { }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
