import SwiftUI
import AppKit

struct PhotoCell: View {
    let photo: PhotoItem
    let isSelected: Bool
    let size: CGFloat
    let onSelectToggle: () -> Void
    let onDoubleClick: () -> Void
    
    @State private var thumbnail: NSImage? = nil
    @State private var isHovering = false
    @State private var showInfoPopover = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail container
                ZStack {
                    Color(NSColor.controlBackgroundColor)
                    
                    if let image = thumbnail {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipped()
                    } else {
                        // Loading placeholder
                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(width: size, height: size)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                
                // Selection Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color.white))
                        .font(.title2)
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Hover Tools Stack (visible on hover)
                if isHovering {
                    VStack(spacing: 8) {
                        Button(action: {
                            showInfoPopover = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .help("Get Info")
                        .popover(isPresented: $showInfoPopover, arrowEdge: .trailing) {
                            PhotoInfoPopoverView(photo: photo)
                        }
                        
                        Button(action: {
                            onDoubleClick()
                        }) {
                            Image(systemName: "eye.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .help("Preview Image")
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.opacity)
                }
                
                // Hover Details Overlay
                if isHovering {
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(photo.filename)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .foregroundColor(.white)
                            
                            Text(photo.creationDateString)
                                .font(.system(size: 8))
                                .lineLimit(1)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                    .frame(width: size, height: size)
                    .cornerRadius(8)
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectToggle()
            }
            .gesture(
                TapGesture(count: 2).onEnded {
                    onDoubleClick()
                }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isHovering = hovering
                }
            }
            
            // Filename label under cell (optional but good for visibility)
            Text(photo.filename)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundColor(isSelected ? .accentColor : .primary)
                .frame(width: size)
                .padding(.top, 2)
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: photo.url) { oldValue, newValue in
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            if let image = await ImageManager.shared.getThumbnail(for: photo.url, size: size * 2) {
                await MainActor.run {
                    self.thumbnail = image
                }
            }
        }
    }
}

struct PhotoInfoPopoverView: View {
    let photo: PhotoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Metadata Details")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Filename", value: photo.filename)
                InfoRow(label: "Location", value: photo.url.path, isPath: true)
                InfoRow(label: "File Size", value: ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                InfoRow(label: "Date Taken", value: photo.creationDateString)
                if let model = photo.cameraModel {
                    InfoRow(label: "Camera Model", value: model)
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isPath: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .center, spacing: 6) {
                Text(value)
                    .font(.system(.body, design: isPath ? .monospaced : .default))
                    .font(.system(size: isPath ? 10 : 12))
                    .lineLimit(isPath ? 3 : 1)
                    .textSelection(.enabled)
                
                if isPath {
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(value, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Copy full path")
                }
            }
        }
    }
}
