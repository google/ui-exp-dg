// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.damowmow.gc

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlin.random.Random
import kotlin.reflect.*
import android.view.WindowManager

const val maxDuration: Long = 30L * 60L * 1000000000L // 30 minutes in nanoseconds
//const val maxDuration: Long = 30L * 1000000000L // 30 seconds in nanoseconds

class MainActivity: FlutterActivity() {
  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    registerBenchmark(flutterEngine, "kotlin.nogc", NoGCKotlinBenchmark())
    registerBenchmark(flutterEngine, "kotlin.immutable", ImmutableKotlinBenchmark())
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    window.setSustainedPerformanceMode(true);
    val backgroundThread = object: Thread("background") {
      // "setSustainedPerformanceMode" is apparently not enough to guarantee that we are
      // in sustained performance mode; we also need a second thread to be running so that
      // we count as multithreaded or some such. (This is based on comments in the JetPack
      // benchmarking library; I couldn't find any documentation.)
      override fun run() {
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_LOWEST)
        while (true) {
          // nop... (hopefully the compiler doesn't optimize this too much)
        }
      }
    }
    backgroundThread.start()
  }

  private fun registerBenchmark(flutterEngine: FlutterEngine, name: String, benchmark: Benchmark) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gc.damowmow.com/$name").setMethodCallHandler {
      call, result ->
      when (call.method) {
        "setup" -> {
          benchmark!!.setup()
          result.success(null)
        }
        "loop" -> {
          var count: Long
          count = 0
          GlobalScope.launch {
            count = benchmark!!.loop()
            withContext(Dispatchers.Main) {
              result.success(count)
            }
          }
        }
        else -> {
          result.notImplemented()
        }
      }

    }
  }
}

const val kArraySize: Int = 1000000
const val kTightLoop: Int = 10000

class IntBox(val value: Int)

abstract class Benchmark {
  open fun setup() { }
  abstract suspend fun loop(): Long
}

class ImmutableKotlinBenchmark: Benchmark() {
  private var array: MutableList<IntBox>? = null
  private val random: Random = Random(0);

  override fun setup() {
    array = MutableList(kArraySize) { IntBox(random.nextInt(kArraySize)) }
  }

  override suspend fun loop(): Long {
    var count: Long = 0
    val endTime: Long = System.nanoTime() + maxDuration
    do {
      for (step in 0 until kTightLoop) {
        count += 1
        val index: Int = array!![(count % kArraySize).toInt()].value + step;
        array!![index % kArraySize] = IntBox((count % kArraySize).toInt())
      }
      yield();
    } while (System.nanoTime() < endTime)
    return count
  }
}

class NoGCKotlinBenchmark: Benchmark() {
  private var array: MutableList<IntBox>? = null
  private var backup: MutableList<IntBox>? = null
  private val random: Random = Random(0);

  override fun setup() {
    array = MutableList(kArraySize) { IntBox(random.nextInt(kArraySize)) }
    backup = array!!.toMutableList()
  }

  fun copy(index: Int): IntBox {
    return backup!![index]
  }

  override suspend fun loop(): Long {
    var count: Long = 0
    val endTime: Long = System.nanoTime() + maxDuration
    do {
      for (step in 0 until kTightLoop) {
        count += 1
        val index: Int = array!![(count % kArraySize).toInt()].value + step;
        array!![index % kArraySize] = copy((count % kArraySize).toInt())
      }
      yield();
    } while (System.nanoTime() < endTime)
    return count
  }
}

