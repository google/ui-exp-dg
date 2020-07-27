# shapes

The same program implemented several different ways.

The program renders a scene of random circles and spinning rectangles. (The scene is random but does not change 
from frame to frame other than the spinning.) There are 10,000 such shapes.

## Implementations

### Flutter

#### Directly to a Skia canvas using Flutter (in `flutter.canvas/`)

This is a straight-forward implementation using Flutter. Essentially this implements the scene description code 
in Dart and the graphics in Skia (C++), rendering to a UIKit view (ObjC).

The drawing code is all in one custom painter; the widget framework is not heavily used by this variant.

#### Flutter widget hierarchy (in `flutter.widgets/`)

This is essentially the same as the previous variant on the C++ side, but the shapes are drawn by independent
widgets and render objects rather than all at once on the Dart side, and the tree has to rebuild each frame to
handle animation changes.

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

### JetPack Compose

This is similar to the Flutter widget hierarchy variant but using JetPack Compose.
