# Copyright 2020 Google LLC. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

use strict;
use warnings;
use Time::HiRes;

use constant size => 100000;

my $watch = Time::HiRes::gettimeofday();
my $index = 0;
while ($index < 10000) {
  my @foo = (1) x size;
  $index += $foo[12487];
}
printf("%.2fs\n", (Time::HiRes::gettimeofday() - $watch));
