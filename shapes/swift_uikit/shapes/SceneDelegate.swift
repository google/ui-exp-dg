// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            let controller = UIViewController()
            controller.view = MyView()
            window.rootViewController = controller
            window.makeKeyAndVisible()
            self.window = window
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

    var angle: Double = 0.0

    func setup() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] timer in
            if (self != nil) {
                self!.angle += 0.01
                self!.setNeedsDisplay()
            }
        }
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)
        let timeAtStart: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        srand48(0)
        for _ in 0..<10000 {
          switch nextInt(2) {
            case 0:
              let radius: Double = nextDouble(min(Double(rect.width), Double(rect.height)) / 8)
              setColor(context, 0xFF000000 + nextInt(0x00FFFFFF))
              let rect: CGRect = CGRect(
                center: CGPoint(x: nextDouble(Double(rect.width) - radius), y: nextDouble(Double(rect.height) - radius)),
                radius: CGFloat(radius)
              )
              context.fillEllipse(in: rect)
            case 1:
              setColor(context, nextInt(0xFFFFFFFF))
              let w: Double = nextDouble(Double(rect.width) / 4)
              let h: Double = nextDouble(Double(rect.height) / 4)
              let x: Double = nextDouble(Double(rect.width) - w)
              let y: Double = nextDouble(Double(rect.height) - h)
              context.saveGState()
              context.translateBy(x: CGFloat(x + w / 2), y: CGFloat(y + h / 2));
              context.rotate(by: CGFloat(angle * nextDouble(2.0) - 1.0));
              context.translateBy(x: CGFloat(-(x + w / 2)), y: CGFloat(-(y + h / 2)));
              context.fill(CGRect(x: x, y: y, width: w,  height: h))
              context.restoreGState()
            default:
              fatalError("math is hard")
          }
        }
        let timeAtEnd: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        print("total frame time: \(String(format: "%.1f", 1000 * (timeAtEnd - timeAtStart)))ms")
        print("--")
    }

    func nextInt(_ max: Int) -> Int {
        return Int(drand48() * Double(max))
    }

    func nextDouble(_ max: Double) -> Double {
        return drand48() * max
    }

    func setColor(_ context: CGContext, _ color: Int) {
        context.setFillColor(CGColor(
            srgbRed: CGFloat(((color >> 16) & 0xFF)) / 255,
            green: CGFloat(((color >> 8) & 0xFF)) / 255,
            blue: CGFloat((color & 0xFF)) / 255,
            alpha: CGFloat(((color >> 24) & 0xFF)) / 255
        ))
    }
}
