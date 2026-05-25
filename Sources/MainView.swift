import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject var viewModel: PhotosViewModel
    
    @State private var previewPhoto: PhotoItem? = nil
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Toolbar
                HStack(spacing: 16) {
                    // Open folder button
                    Button(action: selectSourceFolder) {
                        Label("Open Folder", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.bordered)
                    .help("Open source directory")
                    
                    // Refresh button
                    Button(action: {
                        viewModel.refreshSourceDirectory()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.sourceDirectory == nil)
                    .help("Refresh source grid")
                    
                    Divider().frame(height: 20)
                    
                    // Sort order picker
                    Picker("Sort By", selection: $viewModel.sortOrder) {
                        ForEach(PhotoSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .disabled(viewModel.photos.isEmpty)
                    
                    Spacer()
                    
                    // Thumbnail size slider
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Slider(value: $viewModel.thumbnailSize, in: 100...260)
                            .frame(width: 100)
                        Image(systemName: "photo")
                            .font(.body)
                    }
                    .foregroundColor(.secondary)
                    .disabled(viewModel.photos.isEmpty)
                    
                    Divider().frame(height: 20)
                    
                    // Undo button
                    Button(action: {
                        viewModel.undoLastMove()
                    }) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(viewModel.undoStack.isEmpty)
                    .keyboardShortcut("z", modifiers: .command)
                    .help("Undo last move (Cmd+Z)")
                    
                    // Delete button
                    Button(action: {
                        viewModel.initiateDelete()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(viewModel.selectedPhotoIDs.isEmpty ? .secondary : .red)
                    }
                    .disabled(viewModel.selectedPhotoIDs.isEmpty)
                    .help("Move selected photos to Trash (Delete or Backspace)")
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Main Content (Split View Grid + Sidebar)
                if viewModel.sourceDirectory == nil {
                    WelcomeView(onSelectFolder: selectSourceFolder)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HSplitView {
                        // Left Pane: Grid
                        ZStack {
                            if viewModel.photos.isEmpty && !viewModel.isLoading {
                                EmptyFolderView()
                            } else {
                                PhotoGridView(previewPhoto: $previewPhoto)
                            }
                            
                            if viewModel.isLoading {
                                Color.black.opacity(0.1)
                                    .edgesIgnoringSafeArea(.all)
                                ProgressView("Processing files...")
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.windowBackgroundColor)))
                                    .shadow(radius: 10)
                            }
                        }
                        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Right Pane: Sidebar
                        TargetSidebarView()
                            .frame(minWidth: 260, idealWidth: 300, maxWidth: 400, maxHeight: .infinity)
                    }
                }
                
                Divider()
                
                // Bottom Status Bar
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    
                    Text(viewModel.statusMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if viewModel.sourceDirectory != nil {
                        Text("\(viewModel.selectedPhotoIDs.count) selected  |  \(viewModel.photos.count) remaining")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
            }
            
            // Fullscreen Preview Overlay
            if let photo = previewPhoto {
                PreviewOverlay(photo: photo) {
                    previewPhoto = nil
                }
                .transition(.opacity)
            }
        }
        .alert("Move Photos", isPresented: $viewModel.showMoveConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.pendingTargetFolder = nil
            }
            Button("Move", role: .destructive) {
                if let target = viewModel.pendingTargetFolder {
                    viewModel.executeMove(to: target)
                }
            }
        } message: {
            if let target = viewModel.pendingTargetFolder {
                Text("Are you sure you want to move \(viewModel.selectedPhotoIDs.count) photos to '\(target.name)'?")
            }
        }
        .alert("Delete Photos", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.executeDelete()
            }
        } message: {
            Text("Are you sure you want to move the \(viewModel.selectedPhotoIDs.count) selected photos to the Trash?")
        }
    }
    
    private func selectSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose Source Photo Folder"
        panel.prompt = "Select Source"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    viewModel.loadSourceDirectory(url: url)
                }
            }
        }
    }
}

struct WelcomeView: View {
    let onSelectFolder: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Welcome to Photo Sorter")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Easily select, drag, and sort thousands of photos into custom categories.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            Button(action: onSelectFolder) {
                Text("Choose a Source Folder...")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct EmptyFolderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No photos left in the source directory.")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try opening another folder containing JPG, PNG, HEIC, or RAW files.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
