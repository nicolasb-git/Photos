import SwiftUI

struct PhotoCell: View {
    let photo: PhotoItem
    let isSelected: Bool
    let size: CGFloat
    let onSelectToggle: () -> Void
    let onDoubleClick: () -> Void
    
    @State private var thumbnail: NSImage? = nil
    @State private var isHovering = false
    
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
