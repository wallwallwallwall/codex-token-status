import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "QuotaStatus.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let iconsetURL = outputURL
  .deletingLastPathComponent()
  .appendingPathComponent("QuotaStatus.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(
  at: iconsetURL,
  withIntermediateDirectories: true
)

let variants: [(String, CGFloat)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024),
]

for (fileName, size) in variants {
  let image = drawIcon(size: size)
  let destination = iconsetURL.appendingPathComponent(fileName)
  try image.pngData.write(to: destination)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
  "-c",
  "icns",
  iconsetURL.path,
  "-o",
  outputURL.path,
]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
  throw NSError(
    domain: "QuotaStatusIcon",
    code: Int(process.terminationStatus),
    userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
  )
}

try? FileManager.default.removeItem(at: iconsetURL)

func drawIcon(size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  defer { image.unlockFocus() }

  NSColor.clear.setFill()
  NSRect(x: 0, y: 0, width: size, height: size).fill()

  let scale = size / 1024
  let outerInset = 54 * scale
  let outerRect = NSRect(
    x: outerInset,
    y: outerInset,
    width: size - outerInset * 2,
    height: size - outerInset * 2
  )
  let outerRadius = 218 * scale

  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
  shadow.shadowBlurRadius = 42 * scale
  shadow.shadowOffset = NSSize(width: 0, height: -16 * scale)
  NSGraphicsContext.saveGraphicsState()
  shadow.set()

  let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: outerRadius, yRadius: outerRadius)
  NSGradient(
    colors: [
      NSColor(calibratedRed: 0.02, green: 0.27, blue: 0.25, alpha: 1),
      NSColor(calibratedRed: 0.02, green: 0.10, blue: 0.14, alpha: 1),
      NSColor(calibratedRed: 0.01, green: 0.07, blue: 0.11, alpha: 1),
    ]
  )?.draw(in: outerPath, angle: -45)
  NSGraphicsContext.restoreGraphicsState()

  NSColor.white.withAlphaComponent(0.18).setStroke()
  outerPath.lineWidth = 4 * scale
  outerPath.stroke()

  drawGlow(size: size, scale: scale, rect: outerRect)
  drawStatusLight(scale: scale, rect: outerRect)
  drawOrb(size: size, scale: scale)
  drawBottomPills(size: size, scale: scale)
  drawPercentMark(size: size, scale: scale)

  return image
}

func drawGlow(size: CGFloat, scale: CGFloat, rect: NSRect) {
  let glowRect = NSRect(
    x: rect.minX + 22 * scale,
    y: rect.minY + 520 * scale,
    width: 420 * scale,
    height: 420 * scale
  )
  let glowPath = NSBezierPath(ovalIn: glowRect)
  NSGradient(colors: [
    NSColor(calibratedRed: 0.00, green: 0.86, blue: 0.54, alpha: 0.36),
    NSColor(calibratedRed: 0.00, green: 0.42, blue: 0.40, alpha: 0.00),
  ])?.draw(in: glowPath, relativeCenterPosition: NSPoint(x: -0.12, y: 0.16))
}

func drawStatusLight(scale: CGFloat, rect: NSRect) {
  let ringRect = NSRect(x: rect.minX + 98 * scale, y: rect.maxY - 202 * scale, width: 104 * scale, height: 104 * scale)
  NSColor(calibratedRed: 0.03, green: 0.90, blue: 0.52, alpha: 0.18).setFill()
  NSBezierPath(ovalIn: ringRect).fill()

  let dotRect = ringRect.insetBy(dx: 28 * scale, dy: 28 * scale)
  NSGradient(colors: [
    NSColor(calibratedRed: 0.22, green: 1.00, blue: 0.58, alpha: 1),
    NSColor(calibratedRed: 0.00, green: 0.70, blue: 0.52, alpha: 1),
  ])?.draw(in: NSBezierPath(ovalIn: dotRect), angle: 90)
}

func drawOrb(size: CGFloat, scale: CGFloat) {
  let orbSize = 486 * scale
  let orbRect = NSRect(
    x: (size - orbSize) / 2,
    y: 292 * scale,
    width: orbSize,
    height: orbSize
  )
  let orbPath = NSBezierPath(ovalIn: orbRect)

  let orbShadow = NSShadow()
  orbShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
  orbShadow.shadowBlurRadius = 28 * scale
  orbShadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
  NSGraphicsContext.saveGraphicsState()
  orbShadow.set()

  NSGradient(colors: [
    NSColor(calibratedRed: 0.72, green: 0.96, blue: 0.91, alpha: 1),
    NSColor(calibratedRed: 0.00, green: 0.78, blue: 0.80, alpha: 1),
    NSColor(calibratedRed: 0.00, green: 0.55, blue: 0.78, alpha: 1),
  ])?.draw(in: orbPath, angle: 88)
  NSGraphicsContext.restoreGraphicsState()

  NSColor.white.withAlphaComponent(0.32).setStroke()
  orbPath.lineWidth = 5 * scale
  orbPath.stroke()

  let capRect = NSRect(
    x: orbRect.minX + 56 * scale,
    y: orbRect.maxY - 136 * scale,
    width: orbRect.width - 112 * scale,
    height: 92 * scale
  )
  NSColor.white.withAlphaComponent(0.45).setFill()
  NSBezierPath(roundedRect: capRect, xRadius: 46 * scale, yRadius: 46 * scale).fill()

  let highlightRect = NSRect(
    x: orbRect.minX + 78 * scale,
    y: orbRect.maxY - 168 * scale,
    width: 160 * scale,
    height: 92 * scale
  )
  NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.38),
    NSColor.white.withAlphaComponent(0.00),
  ])?.draw(in: NSBezierPath(ovalIn: highlightRect), relativeCenterPosition: .zero)
}

func drawPercentMark(size: CGFloat, scale: CGFloat) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center

  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 235 * scale, weight: .black),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
    .kern: -5 * scale,
  ]

  let rect = NSRect(x: 0, y: 430 * scale, width: size, height: 240 * scale)
  NSString(string: "%").draw(in: rect, withAttributes: attributes)
}

func drawBottomPills(size: CGFloat, scale: CGFloat) {
  let pillWidth = 236 * scale
  let pillHeight = 104 * scale
  let gap = 38 * scale
  let totalWidth = pillWidth * 2 + gap
  let startX = (size - totalWidth) / 2
  let y = 152 * scale

  let left = NSRect(x: startX, y: y, width: pillWidth, height: pillHeight)
  let right = NSRect(x: startX + pillWidth + gap, y: y, width: pillWidth, height: pillHeight)

  drawPill(rect: left, scale: scale, highlighted: true)
  drawPill(rect: right, scale: scale, highlighted: false)
}

func drawPill(rect: NSRect, scale: CGFloat, highlighted: Bool) {
  let path = NSBezierPath(roundedRect: rect, xRadius: 38 * scale, yRadius: 38 * scale)
  let fill = highlighted
    ? NSColor(calibratedRed: 0.00, green: 0.45, blue: 0.32, alpha: 0.82)
    : NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.30, alpha: 0.88)
  fill.setFill()
  path.fill()

  let stroke = highlighted
    ? NSColor(calibratedRed: 0.00, green: 0.92, blue: 0.52, alpha: 0.55)
    : NSColor.white.withAlphaComponent(0.20)
  stroke.setStroke()
  path.lineWidth = 4 * scale
  path.stroke()
}

extension NSImage {
  var pngData: Data {
    guard let tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffRepresentation),
          let data = bitmap.representation(using: .png, properties: [:]) else {
      fatalError("Unable to render PNG")
    }
    return data
  }
}
