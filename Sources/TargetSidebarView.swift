import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TargetSidebarView: View {
    @EnvironmentObject var viewModel: PhotosViewModel
    
    @State private var showNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var activeDragFolderID: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Target Directories")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Add existing folder
                Button(action: selectExistingFolder) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Add existing target folder")
                
                // Create new folder
                Button(action: {
                    showNewFolderDialog = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Create new folder in source")
                .disabled(viewModel.sourceDirectory == nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            Divider()
            
            // Folder List
            if viewModel.targetFolders.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No target folders")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Click + to add target folders.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(viewModel.targetFolders) { target in
                        TargetFolderRowContainer(target: target, activeDragFolderID: $activeDragFolderID)
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showNewFolderDialog) {
            VStack(spacing: 16) {
                Text("Create Target Folder")
                    .font(.headline)
                
                Text("The folder will be created inside the current source directory:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let source = viewModel.sourceDirectory {
                    Text(source.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
                
                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .onSubmit {
                        createFolderAndDismiss()
                    }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showNewFolderDialog = false
                        newFolderName = ""
                    }
                    
                    Button("Create") {
                        createFolderAndDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 300, height: 200)
        }
    }
    
    private func createFolderAndDismiss() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        viewModel.createNewTargetFolder(named: name)
        showNewFolderDialog = false
        newFolderName = ""
    }
    
    private func selectExistingFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Target Folder"
        panel.prompt = "Add Target"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    viewModel.addTargetFolder(url: url)
                }
            }
        }
    }
}

struct TargetFolderRowContainer: View {
    @EnvironmentObject var viewModel: PhotosViewModel
    let target: TargetFolder
    @Binding var activeDragFolderID: UUID?
    
    var body: some View {
        TargetFolderRow(target: target, isDragOver: activeDragFolderID == target.id)
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { activeDragFolderID == target.id },
                set: { isTargeted in activeDragFolderID = isTargeted ? target.id : nil }
            )) { providers in
                viewModel.initiateMove(to: target)
                activeDragFolderID = nil
                return true
            }
            .contextMenu {
                Button(role: .destructive) {
                    if let index = viewModel.targetFolders.firstIndex(where: { $0.id == target.id }) {
                        viewModel.removeTargetFolder(at: IndexSet(integer: index))
                    }
                } label: {
                    Label("Remove from list", systemImage: "trash")
                }
            }
    }
}

struct TargetFolderRow: View {
    @EnvironmentObject var viewModel: PhotosViewModel
    let target: TargetFolder
    let isDragOver: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundColor(.yellow)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(target.url.path)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Badge counter
            Text("\(target.filesCount)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(NSColor.windowBackgroundColor))
                .clipShape(Capsule())
            
            // "Move here" button
            Button(action: {
                viewModel.initiateMove(to: target)
            }) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedPhotoIDs.isEmpty)
            .help("Move selected photos to this directory")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isDragOver ? Color.accentColor.opacity(0.15) :
            (isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .cornerRadius(6)
        .scaleEffect(isDragOver ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDragOver)
        .onHover { hovering in
            self.isHovered = hovering
        }
    }
}
