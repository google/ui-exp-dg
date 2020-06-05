# shapes

The same program implemented four different ways.

The program renders a scene of random circles and spinning rectangles. (The scene is random but does not change 
from frame to frame other than the spinning.) There are 10,000 such shapes.

## Implementations

There are four implementations.

### Flutter (in `flutter/`)

This is a straight-forward implementation using Flutter. Essentially this implements the scene description code 
in Dart and the graphics in Skia (C++), rendering to a UIKit view (ObjC).

### UIKit using Swift (in `swift_uikit/`)

This is a straight-forward implementation using UIKit in Swift. The scene drawing directly targets CoreGraphics.

### Kotlin + Swift

There are two versions that implement the scene description in Kotlin and the graphics drawing in Swift 
targeting CoreGraphics in a manner similar to the previous one (UIKit using Swift). They are identical except 
for how the two applications communicate.

#### Direct (`kotlin_and_swift_direct`)

This uses the Kotlin/Swift bridge directly as the scene is being drawn. A tree structure is built in Kotlin 
using Kotlin classes and the Swift code queries it as it is targeting CoreGraphics.

#### Buffered (`kotlin_and_swift_buffer`)

This uses a segment of memory to serialize the scene drawn in Kotlin, shares that memory directly with Swift 
without a copy, and then deserializes the buffer into a set of Swift classes that are then queried as the scene 
is drawn to CoreGraphics.

## Conclusions

### Performance

These have not been tested on a real device. On a simulator in debug mode (which isn't a valid comparison point 
but may provide a general guide as to relative performance), the UIKit approach is fastest (~320ms per frame), 
followed by Flutter and the Kotlin + Swift "direct" case (both ~400ms), followed by the Kotlin + Swift using the 
buffer (~575ms). It is likely that these numbers are highly misleading, however.

### Ergonomics

This is highly subjective but the Flutter version benefits from less historical baggage than the pure UIKit 
version (e.g. no casting to CGFloats). The Kotlin versions are hard to evaluate since they are not based on 
production-ready APIs.

The Flutter version benefits from a simpler development environment than either Kotlin or Swift (e.g. fewer 
files, a clearer command line tool, not exposing Gradle out of the box...).
