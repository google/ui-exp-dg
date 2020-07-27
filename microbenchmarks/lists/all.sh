# Copyright 2020 Google LLC. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

echo Dart
dart test.dart
echo

echo C
clang -Ofast test.c && ./a.out
echo

echo Kotlin/Native
kotlinc-native -opt test.kt && ./program.kexe
echo

echo Kotlin on JVM
kotlinc-jvm test.kt -include-runtime -d test.jar && java -jar test.jar
echo

echo FPC
fpc -O4 -v0 test.pas && ./test
echo

echo Perl
perl test.pl
echo

echo Generating JavaScript from Dart and Kotlin
dart2js test.dart -o out.dart.js -O4
kotlinc-js test.kt -output out.kotlin.js
