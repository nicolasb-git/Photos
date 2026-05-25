import SwiftUI
import AppKit

struct PreviewOverlay: View {
    let photo: PhotoItem
    let onDismiss: () -> Void
    
    @State private var previewImage: NSImage? = nil
    @State private var isLoading = true
    @State private var keyMonitor: Any? = nil
    
    var body: some View {
        ZStack {
            // Dark Blur Background
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 16) {
                // Header Details
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(photo.filename)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            Text(photo.creationDateString)
                            Text(formatBytes(photo.fileSize))
                            if let camera = photo.cameraModel {
                                Text(camera)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction) // Esc shortcut
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Image Display
                ZStack {
                    if let image = previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .shadow(radius: 20)
                            .onTapGesture(count: 2) { // double click to dismiss
                                onDismiss()
                            }
                    } else if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Loading high-res preview...")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Failed to load image preview")
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .onAppear {
            loadImage()
            
            // Listen for key presses (Space or Esc to dismiss)
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 || event.keyCode == 53 { // Space or Esc
                    onDismiss()
                    return nil // consume the event
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }
    
    private func loadImage() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            // Check if we can create a medium-sized preview using ImageIO (much faster than loading full 24MP image)
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1200, // Good size for screen preview
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            guard let imageSource = CGImageSourceCreateWithURL(self.photo.url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                
                // Fallback to loading full file if CGImageSource fails (though unlikely)
                if let nsImage = NSImage(contentsOf: self.photo.url) {
                    await MainActor.run {
                        self.previewImage = nsImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
                return
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            await MainActor.run {
                self.previewImage = nsImage
                self.isLoading = false
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
