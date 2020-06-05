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
        );
        let timeBeforeKotlin: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total render time: \(String(format: "%.1f", 1000 * (timeBeforeKotlin - timeAtStart)))ms")
        let rootLayer: Layer = CommonKt.paint(rect: kRect);
        let timeAfterKotlin: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total kotlin time: \(String(format: "%.1f", 1000 * (timeAfterKotlin - timeBeforeKotlin)))ms")
        paintLayer(context, rootLayer)
        let timeAtEnd: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total swift time: \(String(format: "%.1f", 1000 * (timeAtEnd - timeAfterKotlin)))ms")
        print("total frame time: \(String(format: "%.1f", 1000 * (timeAtEnd - timeAtStart)))ms")
        print("--")
        let timeAtStart: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
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
                default: fatalError("Unknown PaintingStyle: \(c.paint.style)")
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
                default: fatalError("Unknown PaintingStyle: \(c.paint.style)")
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
