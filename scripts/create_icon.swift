import AppKit

let size = NSSize(width: 512, height: 512)
let image = NSImage(size: size)

image.lockFocus()

// Rounded squircle background
let bgRect = NSRect(x: 32, y: 32, width: 448, height: 448)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 100, yRadius: 100)

let gradient = NSGradient(starting: NSColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),
                          ending: NSColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1.0))
gradient?.draw(in: bgPath, angle: -45)

// Outer glowing ring
let ringRect = NSRect(x: 76, y: 76, width: 360, height: 360)
let ringPath = NSBezierPath(ovalIn: ringRect)
ringPath.lineWidth = 22
NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
ringPath.stroke()

// Inner arc
let innerRect = NSRect(x: 120, y: 120, width: 272, height: 272)
let innerPath = NSBezierPath()
innerPath.appendArc(withCenter: NSPoint(x: 256, y: 256), radius: 136, startAngle: 180, endAngle: 15, clockwise: false)
innerPath.lineWidth = 14
NSColor.systemCyan.setStroke()
innerPath.stroke()

// Center 'Q' gauge typography
let str = "Q" as NSString
let font = NSFont.systemFont(ofSize: 180, weight: .bold)
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
]
let textSize = str.size(withAttributes: textAttrs)
let textPoint = NSPoint(x: 256 - textSize.width / 2, y: 256 - textSize.height / 2 + 10)
str.draw(at: textPoint, withAttributes: textAttrs)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}

try? pngData.write(to: URL(fileURLWithPath: "/tmp/quotabar_icon_512.png"))
print("Generated 512x512 icon successfully")
