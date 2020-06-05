// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import UIKit
import SharedCode

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            let controller = UIViewController()
            controller.view = MyView()
            window.rootViewController = controller
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

extension CGRect {
    init (center: CGPoint, radius: CGFloat) {
        self.init(x:center.x - radius, y:center.y - radius, width:radius * 2.0, height:radius * 2.0)
    }
}

enum ClassIdentifier: Int {
  case Paint
  case Circle
  case Rectangle
  case Transform
  case DisplayList
  case PaintingLayer
}

class BufferReader {
  var _buffer: [UInt32]
  var _index: Int // in 32 bit words
  init(buffer: [UInt32]) {
    _buffer = buffer
    _index = 0
  }

  func readInt() -> Int32 {
    return Int32(bitPattern: readUInt())
  }

  func readUInt() -> UInt32 {
    _index += 1;
    return UInt32(_buffer[_index - 1])
  }

  func readULong() -> UInt64 {
    _index += 2;
    return UInt64(UInt64(_buffer[_index - 1]) << 32 | UInt64(_buffer[_index - 2]))
  }

  func readLong() -> Int64 {
    return Int64(bitPattern: readULong())
  }

  func readDouble() -> Double {
    return Double(bitPattern: readULong())
  }

  func readClassIdentifier() -> ClassIdentifier {
    return ClassIdentifier(rawValue: Int(readInt()))!
  }

  func readClass() -> Deserializable {
    let identifier: ClassIdentifier = readClassIdentifier()
    switch (identifier) {
        case ClassIdentifier.Paint:
          return Paint.read(buffer: self)
        case ClassIdentifier.Circle:
          return Circle.read(buffer: self)
        case ClassIdentifier.Rectangle:
          return Rectangle.read(buffer: self)
        case ClassIdentifier.Transform:
          return Transform.read(buffer: self)
        case ClassIdentifier.DisplayList:
          return DisplayList.read(buffer: self)
        case ClassIdentifier.PaintingLayer:
          return PaintingLayer.read(buffer: self)
    }
  }
}

protocol Deserializable {}

func deserialize(buffer: BufferReader) -> Deserializable {
  return buffer.readClass()
}

enum PaintingStyle: Int { case fill; case stroke }

class Paint : Deserializable {
  let color: UInt
  let style: PaintingStyle
  init(color: UInt, style: PaintingStyle) {
    self.color = color
    self.style = style
  }
  static func read(buffer: BufferReader) -> Paint {
    let color: UInt = UInt(buffer.readUInt())
    let style: Int = Int(buffer.readInt())
    return Paint(color: color, style: PaintingStyle(rawValue: style)!)
  }
}

protocol DrawOperation: Deserializable {}

class Circle: DrawOperation {
  let x: Double
  let y: Double
  let radius: Double
  let paint: Paint

  init(x: Double, y: Double, radius: Double, paint: Paint) {
    self.x = x
    self.y = y
    self.radius = radius
    self.paint = paint
  }

  static func read(buffer: BufferReader) -> Circle {
    return Circle(x: buffer.readDouble(), y: buffer.readDouble(), radius: buffer.readDouble(), paint: buffer.readClass() as! Paint)
  }
}

class Rectangle: DrawOperation {
  let x: Double
  let y: Double
  let w: Double
  let h: Double
  let paint: Paint

  init(x: Double, y: Double, w: Double, h: Double, paint: Paint) {
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.paint = paint
  }

  static func read(buffer: BufferReader) -> Rectangle {
    return Rectangle(x: buffer.readDouble(), y: buffer.readDouble(), w: buffer.readDouble(), h: buffer.readDouble(), paint: buffer.readClass() as! Paint)
  }
}

// | a11 a12 a13 a14 |
// | a21 a22 a23 a24 |
// | a31 a32 a33 a34 |
// | a41 a42 a43 a44 |
class Transform : DrawOperation {
    let a11: Double
    let a12: Double
    let a13: Double
    let a14: Double
    let a21: Double
    let a22: Double
    let a23: Double
    let a24: Double
    let a31: Double
    let a32: Double
    let a33: Double
    let a34: Double
    let a41: Double
    let a42: Double
    let a43: Double
    let a44: Double
    let child: DrawOperation

    init(
      a11: Double,
      a12: Double,
      a13: Double,
      a14: Double,
      a21: Double,
      a22: Double,
      a23: Double,
      a24: Double,
      a31: Double,
      a32: Double,
      a33: Double,
      a34: Double,
      a41: Double,
      a42: Double,
      a43: Double,
      a44: Double,
      child: DrawOperation
    ) {
      self.a11 = a11
      self.a12 = a12
      self.a13 = a13
      self.a14 = a14
      self.a21 = a21
      self.a22 = a22
      self.a23 = a23
      self.a24 = a24
      self.a31 = a31
      self.a32 = a32
      self.a33 = a33
      self.a34 = a34
      self.a41 = a41
      self.a42 = a42
      self.a43 = a43
      self.a44 = a44
      self.child = child
    }

    static func read(buffer: BufferReader) -> Transform {
      Transform(
        a11: buffer.readDouble(),
        a12: buffer.readDouble(),
        a13: buffer.readDouble(),
        a14: buffer.readDouble(),
        a21: buffer.readDouble(),
        a22: buffer.readDouble(),
        a23: buffer.readDouble(),
        a24: buffer.readDouble(),
        a31: buffer.readDouble(),
        a32: buffer.readDouble(),
        a33: buffer.readDouble(),
        a34: buffer.readDouble(),
        a41: buffer.readDouble(),
        a42: buffer.readDouble(),
        a43: buffer.readDouble(),
        a44: buffer.readDouble(),
        child: buffer.readClass() as! DrawOperation
      )
    }
}

class DisplayList : Deserializable {
  let commands: Array<DrawOperation>

  init(commands: Array<DrawOperation>) {
    self.commands = commands
  }

  static func read(buffer: BufferReader) -> DisplayList {
    let count: Int = Int(buffer.readInt())
    var commands: Array<DrawOperation> = Array<DrawOperation>()
    commands.reserveCapacity(count)
    for _ in 0..<count {
      commands.append(buffer.readClass() as! DrawOperation)
    }
    return DisplayList(commands: commands)
  }
}

protocol Layer : Deserializable {}

class PaintingLayer : Layer {
  let displayList: DisplayList

  init(displayList: DisplayList) {
    self.displayList = displayList
  }

  static func read(buffer: BufferReader) -> PaintingLayer {
    return PaintingLayer(displayList: buffer.readClass() as! DisplayList)
  }
}

class MyView: UIView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    var angle: CGFloat = 0.0

    func setup() {
        CADisplayLink(
            target: self,
            selector: #selector(handleTimer)
        ).add(to: RunLoop.current, forMode: RunLoop.Mode.default)
    }

    @objc func handleTimer(displayLink: CADisplayLink) {
        angle += 0.01
        setNeedsDisplay()
    }

    var timeAtStart: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)
        let kRect = Rect(
            x: Double(rect.minX),
            y: Double(rect.minY),
            w: Double(rect.width),
            h: Double(rect.height)
        )
        let timeBeforeKotlin: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total render time: \(String(format: "%.1f", 1000 * (timeBeforeKotlin - timeAtStart)))ms")
        let bytes = CommonKt.paint(rect: kRect);
        let timeAfterKotlin: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total kotlin time: \(String(format: "%.1f", 1000 * (timeAfterKotlin - timeBeforeKotlin)))ms")
        let byteArray: Array<UInt32> = Array(UnsafeBufferPointer(start: bytes.buffer.bindMemory(to: UInt32.self, capacity: Int(bytes.length) / MemoryLayout<UInt32>.size), count: Int(bytes.length) / MemoryLayout<UInt32>.size))
        let layer = deserialize(buffer: BufferReader(buffer: byteArray)) as! Layer
        let timeAfterDeserialize: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total deserialize time: \(String(format: "%.1f", 1000 * (timeAfterDeserialize - timeAfterKotlin)))ms")
        paintLayer(context, layer)
        bytes.release()
        let timeAtEnd: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total paint time: \(String(format: "%.1f", 1000 * (timeAtEnd - timeAfterDeserialize)))ms")
        print("total frame time: \(String(format: "%.1f", 1000 * (timeAtEnd - timeAtStart)))ms")
        print("---")
        timeAtStart = CFAbsoluteTimeGetCurrent()
    }

    func paintLayer(_ context: CGContext, _ layer: Layer) {
        if (layer is PaintingLayer) {
            paintPaintingLayer(context, layer as! PaintingLayer)
        } else {
            fatalError("Unknown layer type \(type(of: layer))");
        }
    }

    func applyPaint(_ context: CGContext, _ paint: Paint) {
        context.setFillColor(CGColor(
            srgbRed: CGFloat(((paint.color >> 16) & 0xFF)) / 255,
            green: CGFloat(((paint.color >> 8) & 0xFF)) / 255,
            blue: CGFloat((paint.color & 0xFF)) / 255,
            alpha: CGFloat(((paint.color >> 24) & 0xFF)) / 255
        ))
    }

    func drawOperation(_ context: CGContext, _ op: DrawOperation) {
        if (op is Transform) {
            let c = op as! Transform
            let transform = CGAffineTransform(a: CGFloat(c.a11), b: CGFloat(c.a12), c: CGFloat(c.a21), d: CGFloat(c.a22), tx: CGFloat(c.a41), ty: CGFloat(c.a42))
            // TODO(ianh): if transform can't be inverted, this will fail
            context.concatenate(transform)
            drawOperation(context, c.child)
            context.concatenate(transform.inverted())
        } else if (op is Circle) {
            let c = op as! Circle;
            applyPaint(context, c.paint)
            let rect: CGRect = CGRect(
                center: CGPoint(x: c.x, y: c.y),
                radius: CGFloat(c.radius)
            )
            switch (c.paint.style) {
                case PaintingStyle.fill:
                    context.fillEllipse(in: rect)
                case PaintingStyle.stroke:
                    context.strokeEllipse(in: rect)
            }
        } else if (op is Rectangle) {
            let c = op as! Rectangle;
            applyPaint(context, c.paint)
            let rect: CGRect = CGRect(
                x: c.x,
                y: c.y,
                width: c.w,
                height: c.h
            )
            switch (c.paint.style) {
                case PaintingStyle.fill:
                    context.fill(rect)
                case PaintingStyle.stroke:
                    context.stroke(rect)
            }
        } else {
            fatalError("Unknown draw operation type \(type(of: op))")
        }
    }

    func paintPaintingLayer(_ context: CGContext, _ layer: PaintingLayer) {
        for op: DrawOperation in layer.displayList.commands {
            drawOperation(context, op)
        }
    }
}
