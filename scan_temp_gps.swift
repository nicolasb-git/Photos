import Foundation
import ImageIO

let folderPath = "/Users/kaerith/temp"
let directoryURL = URL(fileURLWithPath: folderPath)
let fm = FileManager.default

print("Scanning folder: \(folderPath)")

var isDir: ObjCBool = false
guard fm.fileExists(atPath: folderPath, isDirectory: &isDir), isDir.boolValue else {
    print("Error: Directory \(folderPath) does not exist.")
    exit(1)
}

let allowedExtensions = ["jpg", "jpeg", "png", "heic", "cr2", "nef", "arw", "dng"]

guard let enumerator = fm.enumerator(
    at: directoryURL,
    includingPropertiesForKeys: [.isDirectoryKey],
    options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
) else {
    print("Failed to enumerate directory.")
    exit(1)
}

var foundPhotosCount = 0
var gpsPhotosCount = 0

while let fileURL = enumerator.nextObject() as? URL {
    let ext = fileURL.pathExtension.lowercased()
    guard allowedExtensions.contains(ext) else { continue }
    
    // Skip directories
    var isSubDir = false
    if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]) {
        isSubDir = resourceValues.isDirectory ?? false
    }
    guard !isSubDir else { continue }
    
    foundPhotosCount += 1
    
    // Parse GPS
    if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
       let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary?,
       let gps = properties[kCGImagePropertyGPSDictionary] as? NSDictionary {
        
        let latVal = gps[kCGImagePropertyGPSLatitude]
        let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
        let lonVal = gps[kCGImagePropertyGPSLongitude]
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        
        var latitude: Double? = nil
        var longitude: Double? = nil
        
        if let latNum = latVal, let ref = latRef {
            let lat = (latNum as? NSNumber)?.doubleValue ?? (latNum as? Double) ?? 0.0
            if lat != 0.0 {
                latitude = (ref == "S") ? -lat : lat
            }
        }
        
        if let lonNum = lonVal, let ref = lonRef {
            let lon = (lonNum as? NSNumber)?.doubleValue ?? (lonNum as? Double) ?? 0.0
            if lon != 0.0 {
                longitude = (ref == "W") ? -lon : lon
            }
        }
        
        if let lat = latitude, let lon = longitude {
            gpsPhotosCount += 1
            print("- \(fileURL.lastPathComponent): Lat \(String(format: "%.5f", lat))°, Lon \(String(format: "%.5f", lon))°")
        }
    }
}

print("\n--- Summary ---")
print("Total images found: \(foundPhotosCount)")
print("Images with GPS coordinates: \(gpsPhotosCount)")
