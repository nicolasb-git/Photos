import Foundation
import ImageIO

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("Usage: swift inspect_gps.swift <path_to_image>")
    exit(1)
}

let path = arguments[1]
let url = URL(fileURLWithPath: path)
print("Opening: \(url.path)")

guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
    print("Failed to create image source.")
    exit(1)
}

guard let propertiesRef = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
    print("No properties found.")
    exit(1)
}

let properties = propertiesRef as NSDictionary
print("Root keys: \(properties.allKeys)")

// Check GPS dictionary
let gpsKey = kCGImagePropertyGPSDictionary
if let gps = properties[gpsKey] as? NSDictionary {
    print("GPS Dictionary found:")
    for (key, value) in gps {
        print("  - \(key) (type: \(type(of: value))): \(value)")
    }
    
    // Check specific keys
    let latKey = kCGImagePropertyGPSLatitude
    let latRefKey = kCGImagePropertyGPSLatitudeRef
    let lonKey = kCGImagePropertyGPSLongitude
    let lonRefKey = kCGImagePropertyGPSLongitudeRef
    
    print("\nGPS Parsing check:")
    if let latVal = gps[latKey] {
        print("  Latitude value type: \(type(of: latVal))")
        if let num = latVal as? NSNumber {
            print("    Successfully cast to NSNumber: \(num.doubleValue)")
        } else {
            print("    Failed to cast to NSNumber")
        }
    } else {
        print("  Latitude key (\(latKey)) not found")
    }
    
    if let latRefVal = gps[latRefKey] {
        print("  LatitudeRef value: \(latRefVal)")
    }
    
    if let lonVal = gps[lonKey] {
        print("  Longitude value type: \(type(of: lonVal))")
        if let num = lonVal as? NSNumber {
            print("    Successfully cast to NSNumber: \(num.doubleValue)")
        }
    }
    
    if let lonRefVal = gps[lonRefKey] {
        print("  LongitudeRef value: \(lonRefVal)")
    }
} else {
    print("GPS Dictionary (key: \(gpsKey)) not found.")
}
