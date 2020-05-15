// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.jetbrains.handson.mpp.mobile

import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random
import kotlin.random.nextUInt
import kotlin.time.ExperimentalTime
import kotlin.time.measureTime

enum class SerializableClassIdentifier { Paint, Circle, Rectangle, Transform, DisplayList, PaintingLayer }

data class Rect(val x: Double, val y: Double, val w: Double, val h: Double) {}

enum class PaintingStyle { fill, stroke }

class BufferWriter(var _buffer: UIntArray) {
    private var index: Int = 0
    val currentSize: Int get() = index * 4
    fun writeUInt(value: UInt) {
        _buffer[index] = value
        index += 1;
    }

    fun writeInt(value: Int) {
        _buffer[index] = value.toUInt()
        index += 1;
    }

    fun writeLong(value: Long) {
        _buffer[index] = (value and 0xFFFF_FFFFL).toUInt()
        _buffer[index + 1] = ((value shr 32) and 0xFFFF_FFFFL).toUInt()
        index += 2;
    }

    fun writeDouble(value: Double) {
        writeLong(value.toBits())
    }

    fun writeClassIdentifier(value: SerializableClassIdentifier) {
        writeInt(value.ordinal)
    }
}

abstract class Serializable {
    abstract fun write(buffer: BufferWriter): Unit
}

class Paint(
    val color: UInt = 0x00_000000u,
    val style: PaintingStyle = PaintingStyle.fill
) : Serializable() {
    override fun write(buffer: BufferWriter): Unit { // 12 bytes
        buffer.writeClassIdentifier(SerializableClassIdentifier.Paint)
        buffer.writeUInt(color)
        buffer.writeInt(style.ordinal)
    }
}

abstract class DrawOperation : Serializable() {}

class Circle(
    val x: Double,
    val y: Double,
    val radius: Double,
    val paint: Paint
) : DrawOperation() {
    override fun write(buffer: BufferWriter): Unit { // 40 bytes
        buffer.writeClassIdentifier(SerializableClassIdentifier.Circle)
        buffer.writeDouble(x)
        buffer.writeDouble(y)
        buffer.writeDouble(radius)
        paint.write(buffer)
    }
}

class Rectangle(
    val x: Double,
    val y: Double,
    val w: Double,
    val h: Double,
    val paint: Paint
) : DrawOperation() {
    override fun write(buffer: BufferWriter): Unit { // 48 bytes
        buffer.writeClassIdentifier(SerializableClassIdentifier.Rectangle)
        buffer.writeDouble(x)
        buffer.writeDouble(y)
        buffer.writeDouble(w)
        buffer.writeDouble(h)
        paint.write(buffer)
    }
}

// | a11 a12 a13 a14 |
// | a21 a22 a23 a24 |
// | a31 a32 a33 a34 |
// | a41 a42 a43 a44 |
class Transform(
    val a11: Double,
    val a12: Double,
    val a13: Double,
    val a14: Double,
    val a21: Double,
    val a22: Double,
    val a23: Double,
    val a24: Double,
    val a31: Double,
    val a32: Double,
    val a33: Double,
    val a34: Double,
    val a41: Double,
    val a42: Double,
    val a43: Double,
    val a44: Double,
    val child: DrawOperation
) : DrawOperation() {
    companion object {
        fun rotation(theta: Double, child: DrawOperation): Transform { // radians, clockwise
            val cosTheta: Double = cos(theta);
            val sinTheta: Double = sin(theta)
            return Transform(
                a11 = cosTheta,
                a12 = sinTheta,
                a13 = 0.0,
                a14 = 0.0,
                a21 = -sinTheta,
                a22 = cosTheta,
                a23 = 0.0,
                a24 = 0.0,
                a31 = 0.0,
                a32 = 0.0,
                a33 = 1.0,
                a34 = 0.0,
                a41 = 0.0,
                a42 = 0.0,
                a43 = 0.0,
                a44 = 1.0,
                child = child
            )
        }

        fun translate(
            dx: Double,
            dy: Double,
            child: DrawOperation
        ): Transform { // radians, clockwise
            return Transform(
                a11 = 1.0,
                a12 = 0.0,
                a13 = 0.0,
                a14 = 0.0,
                a21 = 0.0,
                a22 = 1.0,
                a23 = 0.0,
                a24 = 0.0,
                a31 = 0.0,
                a32 = 0.0,
                a33 = 1.0,
                a34 = 0.0,
                a41 = dx,
                a42 = dy,
                a43 = 0.0,
                a44 = 1.0,
                child = child
            )
        }
    }

    override fun write(buffer: BufferWriter): Unit { // 128 bytes plus child
        buffer.writeClassIdentifier(SerializableClassIdentifier.Transform)
        buffer.writeDouble(a11)
        buffer.writeDouble(a12)
        buffer.writeDouble(a13)
        buffer.writeDouble(a14)
        buffer.writeDouble(a21)
        buffer.writeDouble(a22)
        buffer.writeDouble(a23)
        buffer.writeDouble(a24)
        buffer.writeDouble(a31)
        buffer.writeDouble(a32)
        buffer.writeDouble(a33)
        buffer.writeDouble(a34)
        buffer.writeDouble(a41)
        buffer.writeDouble(a42)
        buffer.writeDouble(a43)
        buffer.writeDouble(a44)
        child.write(buffer)
    }
}

class DisplayList(
    val commands: List<DrawOperation>
) : Serializable() {
    override fun write(buffer: BufferWriter): Unit { // 8 bytes plus children
        buffer.writeClassIdentifier(SerializableClassIdentifier.DisplayList)
        buffer.writeInt(commands.count())
        commands.map { it.write(buffer) }
    }
}

abstract class Layer : Serializable() {}

open class PaintingLayer(
    val displayList: DisplayList
) : Layer() {
    override fun write(buffer: BufferWriter): Unit { // 4 bytes plus display list
        buffer.writeClassIdentifier(SerializableClassIdentifier.PaintingLayer)
        displayList.write(buffer)
    }
}

var t: Double = 0.0;

expect class Serialized constructor(root: Serializable) {
    fun release()
}

@ExperimentalTime
@ExperimentalUnsignedTypes
fun paint(rect: Rect): Layer {
    t += 0.01;
    val r = Random(0)
    var rootLayer: Layer
    val time = measureTime {
        rootLayer = PaintingLayer(
            displayList = DisplayList(
                commands = List(10000) {
                    when (r.nextInt(2)) {
                        0 -> { // 40 bytes
                            val radius = r.nextDouble(min(rect.w, rect.h) / 8)
                            Circle(
                                x = r.nextDouble(rect.w - radius),
                                y = r.nextDouble(rect.h - radius),
                                radius = radius,
                                paint = Paint(
                                    color = 0xFF000000u + r.nextUInt(0x00FFFFFFu)
                                )
                            )
                        }
                        1 -> { // 432 bytes
                            val w = r.nextDouble(rect.w / 4)
                            val h = r.nextDouble(rect.h / 4)
                            val x = r.nextDouble(rect.w - w)
                            val y = r.nextDouble(rect.h - h)
                            Transform.translate( // 128 bytes
                                x + w / 2, y + h / 2,
                                Transform.rotation( // 128 bytes
                                    t * (r.nextDouble(2.0) - 1.0),
                                    Transform.translate( // 128 bytes
                                        -(x + w / 2), -(y + h / 2),
                                        Rectangle( // 48 bytes
                                            x = x,
                                            y = y,
                                            w = w,
                                            h = h,
                                            paint = Paint(
                                                color = r.nextUInt(0xFFFFFFFFu)
                                            )
                                        )
                                    )
                                )
                            )
                        }
                        else -> {
                            throw Exception("unreachable")
                        }
                    }
                }
            )
        )
    }
    println("total generation time: $time")
    return rootLayer
//    return Serialized(rootLayer)
}
