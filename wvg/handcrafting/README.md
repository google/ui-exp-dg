# wvg-handcrafter

This tool converts .wvgtxt files into .wvg files.

For details on WVG see: https://docs.google.com/document/d/1YWffrlc6ZqRwfIiR1qwp1AOkS9JyA_lEURI8p5PsZlg/edit#heading=h.pxxrvu173kmw

## .wvgtxt

This format was created to make it easier to create WVG files by hand.

It attempts to stay very close to the WVG format, but has many
conveniences to make it easier to express.

The .wvgtxt format is text based. The character
encoding expected by the converter tool is UTF-8.

### Format overview

A block has the following form:

```
[label:] type { data... }
```

Data in a block usually consists of words, words can be the following:

* floating point number (e.g. 1.0, 2e6, -19.2).
* decimal integer (e.g. -2, 5).
* hex integer (0x11223344).
* reference to another block, whose interpretation depends on context,
  given as an @ sign followed by the block's label (e.g. @foo).
* constant:
   * "linear" is 0x10
   * "radial" is 0x14
   * "negate-int" is 0x80000000
   * "negate" is 0x80010000
   * "as-int" is 0x80008000
   * "as-float" is 0x80018000
   * "duplicate" is 0x80020000
   * "add-int" is 0xC0000001
   * "subtract-int" is 0xC0000002
   * "multiply-int" is 0xC0000003
   * "divide-int" is 0xC0000004
   * "+" is 0xC0010001
   * "-" is 0xC0010002
   * "*" is 0xC0010003
   * "/" is 0xC0010004

Words are typically space-separated.

Some data blocks are lists of lists of words, in which case each outer
list are semicolon separated.

A file consists of zero or more of the following blocks:

* `metadata`: data is arbitrary words.
* `parameter`: data is arbitrary words.
* `expression`: data is arbitrary words
* `matrix`: data is a list of 16 words.
* `shape`: data is a list of lists of words.
* `gradient`: two lists or words.
* `paint`: list of words.
* `draw`: list of words (usually references to a matrix, a shape, and
  a paint, expression, or parameter).

The following blocks can also be used:

* `rawcurve`: data is a list of words.
* `rawshape`: data is two words: reference to a curve and number of curves.
* `raw NN`: data is arbitrary words. NN refers to the block number (0-62).


### Example

```wvgtxt
metadata { 10 10 }
foo: parameter { 10 }
bar: expression { @foo 2.0 + }
baz: matrix {
  1 0 0 @shiftx
  0 1 0 @shifty
  0 0 1 0
  0 0 0 1
}
zap: rawcurve { 1.0 1.0 20.0 2.0 5.0 0xFFFFFFFF 0xFFFFFFFF 0xFFFFFFFF }
rawcurve { 0xFFFFFFFF }
quux: rawshape { @zap 10 }
zip: shape {
  1.0 1.0 20.0 2.0 5.0;
  1.0 1.0 20.0 2.0 5.0 6.0
}
zooee: gradient {
  0.0        0.2 0.4        @foo       @bar;
  0x11223344 bar 0x11223344 0x11223344 0x11223344
}
bloop: paint { linear @zooee 0x00000000 0.0 0.0 0.0 1.0 }
bleep: paint { radial @zooee 0x00000000 @baz }
draw { @baz @zip @bloop }
```
