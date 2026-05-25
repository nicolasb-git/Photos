import Cocoa
import ImageIO
import UniformTypeIdentifiers

let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let testSourceDir = URL(fileURLWithPath: currentDir).appendingPathComponent("TestSourcePhotos")

try? fileManager.createDirectory(at: testSourceDir, withIntermediateDirectories: true, attributes: nil)

print("=== Generating 100 mock images in \(testSourceDir.path) ===")

for i in 1...100 {
    let size = CGSize(width: 400, height: 300)
    let image = NSImage(size: size)
    
    // Draw a random solid color
    image.lockFocus()
    let color = NSColor(
        red: CGFloat.random(in: 0...1),
        green: CGFloat.random(in: 0...1),
        blue: CGFloat.random(in: 0...1),
        alpha: 1.0
    )
    color.set()
    let rect = NSRect(origin: .zero, size: size)
    rect.fill()
    
    // Draw label text in center
    let text = "Photo \(i)"
    let attrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.white,
        .font: NSFont.systemFont(ofSize: 24, weight: .bold)
    ]
    let textWidth = (text as NSString).size(withAttributes: attrs).width
    let textHeight = (text as NSString).size(withAttributes: attrs).height
    let textRect = NSRect(
        x: (size.width - textWidth) / 2,
        y: (size.height - textHeight) / 2,
        width: textWidth,
        height: textHeight
    )
    (text as NSString).draw(in: textRect, withAttributes: attrs)
    
    image.unlockFocus()
    
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        continue
    }
    
    let fileURL = testSourceDir.appendingPathComponent("MockPhoto_\(String(format: "%03d", i)).jpg")
    
    // Create image destination with metadata using ImageIO
    guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        continue
    }
    
    // Set EXIF Metadata (creation date offset by i hours to test date sorting)
    let calendar = Calendar.current
    let offsetDate = calendar.date(byAdding: .hour, value: -i, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    let dateStr = formatter.string(from: offsetDate)
    
    let exifMetadata: [CFString: Any] = [
        kCGImagePropertyExifDateTimeOriginal: dateStr
    ]
    
    let tiffMetadata: [CFString: Any] = [
        kCGImagePropertyTIFFModel: "Mock Camera X\(i % 3 + 1)"
    ]
    
    let metadata: [CFString: Any] = [
        kCGImagePropertyExifDictionary: exifMetadata,
        kCGImagePropertyTIFFDictionary: tiffMetadata
    ]
    
    CGImageDestinationAddImage(destination, bitmap.cgImage!, metadata as CFDictionary)
    CGImageDestinationFinalize(destination)
}

print("=== Successfully generated 100 mock images with EXIF data! ===")
