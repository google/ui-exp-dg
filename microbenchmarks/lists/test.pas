// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

{$MODE OBJFPC}
uses SysUtils, DateUtils;

const
   Size = 100000;
var
   Watch: TDateTime;
   Index, Subindex: Integer;
   Foo: array[0..Size-1] of Integer;
begin
   Watch := Now;
   Index := 0;
   while (Index < 10000) do
   begin
      for Subindex := 0 to Size - 1 do
         Foo[Subindex] := 1;
      Index += Foo[12487];
   end;
   WriteLn(Format('%.2fs', [(Now - Watch) * 24 * 60 * 60]));
end.
