import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func color(_ hex: UInt32) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255.0
    let green = CGFloat((hex >> 8) & 0xff) / 255.0
    let blue = CGFloat(hex & 0xff) / 255.0
    return CGColor(red: red, green: green, blue: blue, alpha: 1)
}

func drawIcon(size: Int) -> NSImage {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let canvas = CGRect(x: 0, y: 0, width: side, height: side)
    context.setFillColor(color(0xEAF3FF))
    context.fill(canvas)

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0xEAF3FF), color(0xE8F8F0)] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: side * 0.08, y: side * 0.92),
        end: CGPoint(x: side * 0.92, y: side * 0.08),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    context.setStrokeColor(color(0xD9EAFE))
    context.setLineWidth(side * 0.018)
    context.strokeEllipse(in: canvas.insetBy(dx: side * 0.08, dy: side * 0.08))

    let plate = canvas.insetBy(dx: side * 0.18, dy: side * 0.18)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -side * 0.035),
        blur: side * 0.07,
        color: CGColor(red: 0.06, green: 0.13, blue: 0.22, alpha: 0.13)
    )
    context.setFillColor(color(0xFFFFFF))
    context.fillEllipse(in: plate)
    context.restoreGState()

    context.setStrokeColor(color(0xD1D6DB))
    context.setLineWidth(side * 0.026)
    context.strokeEllipse(in: plate.insetBy(dx: side * 0.105, dy: side * 0.105))

    let route = CGMutablePath()
    route.move(to: CGPoint(x: side * 0.28, y: side * 0.37))
    route.addCurve(
        to: CGPoint(x: side * 0.62, y: side * 0.34),
        control1: CGPoint(x: side * 0.39, y: side * 0.27),
        control2: CGPoint(x: side * 0.52, y: side * 0.46)
    )
    context.setLineCap(.round)
    context.setStrokeColor(color(0x3182F6))
    context.setLineWidth(side * 0.045)
    context.addPath(route)
    context.strokePath()

    context.setFillColor(color(0x3182F6))
    for point in [
        CGPoint(x: side * 0.30, y: side * 0.38),
        CGPoint(x: side * 0.47, y: side * 0.35),
        CGPoint(x: side * 0.62, y: side * 0.34),
    ] {
        let radius = side * 0.032
        context.fillEllipse(
            in: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }

    let largeLeaf = CGMutablePath()
    largeLeaf.move(to: CGPoint(x: side * 0.46, y: side * 0.48))
    largeLeaf.addCurve(
        to: CGPoint(x: side * 0.74, y: side * 0.66),
        control1: CGPoint(x: side * 0.50, y: side * 0.70),
        control2: CGPoint(x: side * 0.66, y: side * 0.76)
    )
    largeLeaf.addCurve(
        to: CGPoint(x: side * 0.46, y: side * 0.48),
        control1: CGPoint(x: side * 0.73, y: side * 0.48),
        control2: CGPoint(x: side * 0.58, y: side * 0.39)
    )
    largeLeaf.closeSubpath()
    context.setFillColor(color(0x00A86B))
    context.addPath(largeLeaf)
    context.fillPath()

    let smallLeaf = CGMutablePath()
    smallLeaf.move(to: CGPoint(x: side * 0.47, y: side * 0.48))
    smallLeaf.addCurve(
        to: CGPoint(x: side * 0.34, y: side * 0.67),
        control1: CGPoint(x: side * 0.32, y: side * 0.60),
        control2: CGPoint(x: side * 0.30, y: side * 0.72)
    )
    smallLeaf.addCurve(
        to: CGPoint(x: side * 0.47, y: side * 0.48),
        control1: CGPoint(x: side * 0.48, y: side * 0.68),
        control2: CGPoint(x: side * 0.54, y: side * 0.57)
    )
    smallLeaf.closeSubpath()
    context.setFillColor(color(0x25C685))
    context.addPath(smallLeaf)
    context.fillPath()

    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: side * 0.39, y: side * 0.42))
    stem.addCurve(
        to: CGPoint(x: side * 0.66, y: side * 0.62),
        control1: CGPoint(x: side * 0.48, y: side * 0.50),
        control2: CGPoint(x: side * 0.57, y: side * 0.57)
    )
    context.setStrokeColor(color(0xFFFFFF))
    context.setLineWidth(side * 0.035)
    context.addPath(stem)
    context.strokePath()

    context.setFillColor(color(0xFFB020))
    let accentRadius = side * 0.045
    context.fillEllipse(
        in: CGRect(
            x: side * 0.65,
            y: side * 0.29,
            width: accentRadius * 2,
            height: accentRadius * 2
        )
    )

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to render \(url.path)")
    }
    try! FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try! data.write(to: url)
}

let master = drawIcon(size: 1024)
writePNG(master, to: root.appendingPathComponent("assets/app_icon/diet_project_icon_1024.png"))

let androidIcons: [(String, Int)] = [
    ("mipmap-mdpi/ic_launcher.png", 48),
    ("mipmap-hdpi/ic_launcher.png", 72),
    ("mipmap-xhdpi/ic_launcher.png", 96),
    ("mipmap-xxhdpi/ic_launcher.png", 144),
    ("mipmap-xxxhdpi/ic_launcher.png", 192),
]

for icon in androidIcons {
    writePNG(
        drawIcon(size: icon.1),
        to: root.appendingPathComponent("android/app/src/main/res/\(icon.0)")
    )
}

let appIconDirectory = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let contentsURL = appIconDirectory.appendingPathComponent("Contents.json")
let contentsData = try! Data(contentsOf: contentsURL)
let contents = try! JSONSerialization.jsonObject(with: contentsData) as! [String: Any]
let images = contents["images"] as! [[String: String]]
var renderedIOSFiles = Set<String>()

for imageInfo in images {
    guard
        let filename = imageInfo["filename"],
        let sizeText = imageInfo["size"]?.split(separator: "x").first,
        let pointSize = Double(sizeText),
        let scaleText = imageInfo["scale"]?.replacingOccurrences(of: "x", with: ""),
        let scale = Double(scaleText)
    else {
        continue
    }
    if renderedIOSFiles.contains(filename) {
        continue
    }
    renderedIOSFiles.insert(filename)
    let pixels = Int((pointSize * scale).rounded())
    writePNG(
        drawIcon(size: pixels),
        to: appIconDirectory.appendingPathComponent(filename)
    )
}

let webIcons: [(String, Int)] = [
    ("web/icons/Icon-192.png", 192),
    ("web/icons/Icon-maskable-192.png", 192),
    ("web/icons/Icon-512.png", 512),
    ("web/icons/Icon-maskable-512.png", 512),
]

for icon in webIcons {
    writePNG(drawIcon(size: icon.1), to: root.appendingPathComponent(icon.0))
}
