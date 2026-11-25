import AppKit

enum ExportError: Error {
    case invalidArguments
    case unreadableSource
    case bitmapCreationFailed
    case pngEncodingFailed
}

guard CommandLine.arguments.count == 3 else {
    throw ExportError.invalidArguments
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)

guard let source = NSImage(contentsOf: sourceURL) else {
    throw ExportError.unreadableSource
}

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

func render(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw ExportError.bitmapCreationFailed
    }

    bitmap.size = NSSize(width: size, height: size)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let scale = CGFloat(size) / 1024
    let iconBounds = NSRect(
        x: 76 * scale,
        y: 62 * scale,
        width: 872 * scale,
        height: 896 * scale
    )
    NSBezierPath(
        roundedRect: iconBounds,
        xRadius: 170 * scale,
        yRadius: 170 * scale
    ).addClip()

    source.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: source.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw ExportError.pngEncodingFailed
    }
    return data
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let outputURL = outputDirectory.appendingPathComponent("AppIcon-\(size).png")
    try render(size: size).write(to: outputURL, options: .atomic)
}
