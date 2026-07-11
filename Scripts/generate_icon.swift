import AppKit

let size: CGFloat = 1024
let symbolSize: CGFloat = 580
let dest = URL(fileURLWithPath: CommandLine.arguments[1])

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let bgPath = CGPath(roundedRect: rect, cornerWidth: 200, cornerHeight: 200, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Gradient background — purple to deep blue
    let colors = [
        CGColor(red: 0.45, green: 0.25, blue: 0.75, alpha: 1.0),
        CGColor(red: 0.15, green: 0.20, blue: 0.60, alpha: 1.0),
        CGColor(red: 0.05, green: 0.10, blue: 0.35, alpha: 1.0),
    ]
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: [0.0, 0.5, 1.0]
    )!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])

    // Draw x.squareroot SF Symbol in white
    let symbolName = "x.squareroot"
    guard let symbolImg = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        return false
    }
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
    guard let configured = symbolImg.withSymbolConfiguration(config) else { return false }

    let symbolRect = CGRect(
        x: (size - symbolSize) / 2,
        y: (size - symbolSize) / 2,
        width: symbolSize,
        height: symbolSize
    )

    // Force dark appearance so template symbols render as white
    let previousAppearance = NSAppearance.current
    NSAppearance.current = NSAppearance(named: .darkAqua) ?? previousAppearance
    configured.draw(in: symbolRect)
    NSAppearance.current = previousAppearance

    return true
}

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    fatalError("Failed to create PNG")
}
try pngData.write(to: dest)
print("Icon generated: \(dest.path)")
