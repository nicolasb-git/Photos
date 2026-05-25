import Cocoa
import ImageIO
import UniformTypeIdentifiers

public final class ImageManager: Sendable {
    public static let shared = ImageManager()
    
    private let cacheDirectory: URL
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let appCache = paths[0].appendingPathComponent("com.photosorter.app", isDirectory: true)
        let thumbs = appCache.appendingPathComponent("thumbnails", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true, attributes: nil)
        self.cacheDirectory = thumbs
    }
    
    private func cacheURL(for fileURL: URL) -> URL {
        var modDate = ""
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let mDate = attrs[.modificationDate] as? Date {
            modDate = "\(mDate.timeIntervalSince1970)"
        }
        let uniqueString = "\(fileURL.path)_\(modDate)"
        let hashStr = String(format: "%016llx", abs(Int64(uniqueString.hashValue)))
        return cacheDirectory.appendingPathComponent("\(hashStr).png")
    }
    
    public func getThumbnail(for fileURL: URL, size: CGFloat = 200) async -> NSImage? {
        let cachedFile = cacheURL(for: fileURL)
        
        // Check cache first
        if FileManager.default.fileExists(atPath: cachedFile.path) {
            return NSImage(contentsOf: cachedFile)
        }
        
        // Otherwise, generate thumbnail on background thread
        return await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let cgImage = self.generateThumbnail(from: fileURL, size: size) else {
                return nil
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
            
            // Save to disk cache
            if let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: cachedFile)
            }
            
            return nsImage
        }.value
    }
    
    private func generateThumbnail(from fileURL: URL, size: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }
        
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
    
    public func getMetadata(for fileURL: URL) -> (creationDate: Date, cameraModel: String?, latitude: Double?, longitude: Double?) {
        var creationDate = Date()
        var cameraModel: String? = nil
        var latitude: Double? = nil
        var longitude: Double? = nil
        
        if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) {
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary? {
                // 1. Try Exif DateTimeOriginal
                if let exif = properties[kCGImagePropertyExifDictionary] as? NSDictionary {
                    if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        if let date = formatter.date(from: dateStr) {
                            creationDate = date
                        }
                    }
                }
                
                // 2. Try TIFF Model
                if let tiff = properties[kCGImagePropertyTIFFDictionary] as? NSDictionary {
                    cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
                }
                
                // 3. Try GPS Dictionary
                if let gps = properties[kCGImagePropertyGPSDictionary] as? NSDictionary {
                    if let latVal = gps[kCGImagePropertyGPSLatitude],
                       let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
                        let lat = (latVal as? NSNumber)?.doubleValue ?? (latVal as? Double) ?? 0.0
                        if lat != 0.0 {
                            latitude = (latRef == "S") ? -lat : lat
                        }
                    }
                    if let lonVal = gps[kCGImagePropertyGPSLongitude],
                       let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                        let lon = (lonVal as? NSNumber)?.doubleValue ?? (lonVal as? Double) ?? 0.0
                        if lon != 0.0 {
                            longitude = (lonRef == "W") ? -lon : lon
                        }
                    }
                }
            }
        }
        
        // 4. Fallback to file creation date if EXIF parser did not succeed
        if creationDate.timeIntervalSince1970 > Date().timeIntervalSince1970 - 10 { // near now
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fsCreationDate = attributes[.creationDate] as? Date {
                creationDate = fsCreationDate
            }
        }
        
        return (creationDate, cameraModel, latitude, longitude)
    }
    
    public func clearCache() {
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
