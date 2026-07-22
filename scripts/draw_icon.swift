// Generates Resources/AppIcon.icns source art (1024×1024 PNG).
// Run via: swift scripts/draw_icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/tomochi_icon.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS-style rounded square with margins.
let inset: CGFloat = 90
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let clip = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
clip.addClip()

// Warm peach gradient background.
NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.85, blue: 0.65, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.39, alpha: 1),
])!.draw(in: rect, angle: -90)

let cream = NSColor(calibratedRed: 1.00, green: 0.99, blue: 0.97, alpha: 1)
let pink = NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.70, alpha: 1)
let brown = NSColor(calibratedRed: 0.36, green: 0.27, blue: 0.21, alpha: 1)

func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, color: NSColor) {
    let p = NSBezierPath()
    p.move(to: a); p.line(to: b); p.line(to: c); p.close()
    color.setFill(); p.fill()
}

// Ears (behind the head), with pink inner ears.
triangle(CGPoint(x: 305, y: 650), CGPoint(x: 262, y: 905), CGPoint(x: 505, y: 735), color: cream)
triangle(CGPoint(x: 719, y: 650), CGPoint(x: 762, y: 905), CGPoint(x: 519, y: 735), color: cream)
triangle(CGPoint(x: 322, y: 700), CGPoint(x: 296, y: 852), CGPoint(x: 448, y: 745), color: pink)
triangle(CGPoint(x: 702, y: 700), CGPoint(x: 728, y: 852), CGPoint(x: 576, y: 745), color: pink)

// Head.
let head = NSBezierPath(ovalIn: NSRect(x: 512 - 280, y: 480 - 280, width: 560, height: 560))
cream.setFill(); head.fill()

// Closed happy eyes: ∩ arcs.
brown.setStroke()
for cx: CGFloat in [402, 622] {
    let eye = NSBezierPath()
    eye.appendArc(withCenter: CGPoint(x: cx, y: 520), radius: 42, startAngle: 20, endAngle: 160)
    eye.lineWidth = 26
    eye.lineCapStyle = .round
    eye.stroke()
}

// Blush.
NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.70, alpha: 0.45).setFill()
NSBezierPath(ovalIn: NSRect(x: 330, y: 415, width: 84, height: 46)).fill()
NSBezierPath(ovalIn: NSRect(x: 610, y: 415, width: 84, height: 46)).fill()

// Nose.
let nose = NSBezierPath()
nose.move(to: CGPoint(x: 512 - 24, y: 468))
nose.line(to: CGPoint(x: 512 + 24, y: 468))
nose.line(to: CGPoint(x: 512, y: 434))
nose.close()
pink.setFill(); nose.fill()

// Mouth: little "w".
let mouth = NSBezierPath()
mouth.move(to: CGPoint(x: 512, y: 430))
mouth.appendArc(withCenter: CGPoint(x: 487, y: 430), radius: 25, startAngle: 0, endAngle: 200, clockwise: true)
mouth.move(to: CGPoint(x: 562, y: 430))
mouth.appendArc(withCenter: CGPoint(x: 537, y: 430), radius: 25, startAngle: 340, endAngle: 180, clockwise: true)
mouth.lineWidth = 16
mouth.lineCapStyle = .round
brown.setStroke(); mouth.stroke()

// Whiskers.
NSColor(calibratedRed: 0.36, green: 0.27, blue: 0.21, alpha: 0.65).setStroke()
let whiskers: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 318, y: 500), CGPoint(x: 205, y: 522)),
    (CGPoint(x: 318, y: 455), CGPoint(x: 200, y: 448)),
    (CGPoint(x: 706, y: 500), CGPoint(x: 819, y: 522)),
    (CGPoint(x: 706, y: 455), CGPoint(x: 824, y: 448)),
]
for (a, b) in whiskers {
    let w = NSBezierPath()
    w.move(to: a); w.line(to: b)
    w.lineWidth = 12
    w.lineCapStyle = .round
    w.stroke()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
