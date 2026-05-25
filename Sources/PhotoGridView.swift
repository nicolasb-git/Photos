import SwiftUI
import UniformTypeIdentifiers

struct PhotoGridView: View {
    @EnvironmentObject var viewModel: PhotosViewModel
    @Binding var previewPhoto: PhotoItem?
    
    @State private var lastClickedID: UUID? = nil
    @State private var keyboardMonitor: Any? = nil
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: viewModel.thumbnailSize, maximum: viewModel.thumbnailSize + 40), spacing: 16)],
                spacing: 20
            ) {
                ForEach(viewModel.photos) { photo in
                    PhotoCell(
                        photo: photo,
                        isSelected: viewModel.selectedPhotoIDs.contains(photo.id),
                        size: viewModel.thumbnailSize,
                        onSelectToggle: {
                            handleSelection(for: photo)
                        },
                        onDoubleClick: {
                            previewPhoto = photo
                        }
                    )
                    .onDrag {
                        // Ensure the dragged item is selected
                        if !viewModel.selectedPhotoIDs.contains(photo.id) {
                            viewModel.toggleSelection(for: photo.id)
                        }
                        
                        // We pass the URL of the dragged item
                        let provider = NSItemProvider(item: photo.url as NSURL, typeIdentifier: UTType.fileURL.identifier)
                        return provider
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.underPageBackgroundColor))
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
    }
    
    private func handleSelection(for photo: PhotoItem) {
        let modifierFlags = NSEvent.modifierFlags
        let isCmd = modifierFlags.contains(.command)
        let isShift = modifierFlags.contains(.shift)
        
        if isShift, let startID = lastClickedID {
            // Shift selection
            viewModel.selectRange(from: startID, to: photo.id)
        } else if isCmd {
            // Cmd selection toggles
            viewModel.toggleSelection(for: photo.id)
            lastClickedID = photo.id
        } else {
            // Regular selection selects only this item
            viewModel.clearSelection()
            viewModel.toggleSelection(for: photo.id)
            lastClickedID = photo.id
        }
    }
    
    private func setupKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only monitor if the key window is active and it is the main window
            guard let window = NSApp.keyWindow, window == NSApp.mainWindow else {
                return event
            }
            
            if let responder = window.firstResponder {
                let className = responder.className
                if className.contains("Text") || responder is NSText {
                    return event
                }
            }
            
            let isCmd = event.modifierFlags.contains(.command)
            
            if event.keyCode == 49 { // Space bar
                if !viewModel.selectedPhotoIDs.isEmpty {
                    // Preview the first selected item
                    if let firstSelected = viewModel.photos.first(where: { viewModel.selectedPhotoIDs.contains($0.id) }) {
                        self.previewPhoto = firstSelected
                    }
                    return nil // consume event
                }
            } else if isCmd && event.charactersIgnoringModifiers == "a" {
                viewModel.selectAll()
                return nil // consume event
            } else if isCmd && event.charactersIgnoringModifiers == "z" {
                viewModel.undoLastMove()
                return nil // consume event
            } else if event.keyCode == 51 || event.keyCode == 117 { // Backspace or Delete
                if !viewModel.selectedPhotoIDs.isEmpty {
                    viewModel.initiateDelete()
                    return nil // consume event
                }
            } else if event.keyCode == 53 { // Escape
                viewModel.clearSelection()
                return nil // consume event
            }
            
            return event
        }
    }
}
