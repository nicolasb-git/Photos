import Foundation
import SwiftUI
import Combine

@MainActor
public final class PhotosViewModel: ObservableObject {
    @Published public var sourceDirectory: URL? = nil
    @Published public var photos: [PhotoItem] = []
    @Published public var selectedPhotoIDs: Set<UUID> = []
    @Published public var targetFolders: [TargetFolder] = []
    @Published public var undoStack: [UndoAction] = []
    @Published public var statusMessage: String = ""
    @Published public var isLoading: Bool = false
    @Published public var sortOrder: PhotoSortOption = .name {
        didSet {
            sortPhotos()
        }
    }
    @Published public var thumbnailSize: CGFloat = 160
    
    // For confirmation dialogs
    @Published public var showMoveConfirmation = false
    @Published public var pendingTargetFolder: TargetFolder? = nil
    
    private let fileManager = FileManager.default
    private static let allowedExtensions = ["jpg", "jpeg", "png", "heic", "cr2", "nef", "arw", "dng"]
    
    public init() {
        loadSession()
    }
    
    // MARK: - Session Management
    
    public func saveSession() {
        let targetPaths = targetFolders.map { $0.url.path }
        logDebug("saveSession: Saving targetPaths: \(targetPaths)")
        UserDefaults.standard.set(targetPaths, forKey: "PhotosSorterTargetPaths")
        if let sourcePath = sourceDirectory?.path {
            logDebug("saveSession: Saving sourcePath: \(sourcePath)")
            UserDefaults.standard.set(sourcePath, forKey: "PhotosSorterSourcePath")
        } else {
            logDebug("saveSession: Removing sourcePath")
            UserDefaults.standard.removeObject(forKey: "PhotosSorterSourcePath")
        }
    }
    
    private func loadSession() {
        logDebug("loadSession: Starting loadSession")
        // Load targets
        if let targetPaths = UserDefaults.standard.stringArray(forKey: "PhotosSorterTargetPaths") {
            logDebug("loadSession: Found targetPaths in UserDefaults: \(targetPaths)")
            self.targetFolders = targetPaths.compactMap { path in
                let url = URL(fileURLWithPath: path)
                var isDir = false
                if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]) {
                    isDir = resourceValues.isDirectory ?? false
                }
                if isDir {
                    let fileCount = countFilesInDirectory(url)
                    logDebug("loadSession: Successfully loaded target: \(url.path) with \(fileCount) files")
                    return TargetFolder(url: url, filesCount: fileCount)
                }
                logDebug("loadSession: Target directory does not exist or is not a dir: \(url.path)")
                return nil
            }
        } else {
            logDebug("loadSession: No targetPaths found in UserDefaults")
        }
        
        // Load last source directory
        if let sourcePath = UserDefaults.standard.string(forKey: "PhotosSorterSourcePath") {
            logDebug("loadSession: Found sourcePath in UserDefaults: \(sourcePath)")
            let url = URL(fileURLWithPath: sourcePath)
            var isDir = false
            if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]) {
                isDir = resourceValues.isDirectory ?? false
            }
            if isDir {
                loadSourceDirectory(url: url)
            } else {
                logDebug("loadSession: Source directory does not exist or is not a dir: \(url.path)")
            }
        }
    }
    
    // MARK: - Directory Loading
    
    public func loadSourceDirectory(url: URL) {
        logDebug("loadSourceDirectory: Loading source: \(url.path)")
        self.sourceDirectory = url
        self.statusMessage = "Loading directory..."
        self.isLoading = true
        self.selectedPhotoIDs.removeAll()
        self.saveSession()
        
        Task {
            let loadedPhotos = await loadPhotosAsync(from: url)
            await MainActor.run {
                self.photos = loadedPhotos
                self.sortPhotos()
                self.isLoading = false
                self.statusMessage = "Loaded \(self.photos.count) photos."
                self.logDebug("loadSourceDirectory: Finished loading \(self.photos.count) photos.")
            }
        }
    }
    
    private func loadPhotosAsync(from directoryURL: URL) async -> [PhotoItem] {
        let allowedExts = PhotosViewModel.allowedExtensions
        return await Task.detached(priority: .userInitiated) { () -> [PhotoItem] in
            var items: [PhotoItem] = []
            let fm = FileManager.default
            
            guard let enumerator = fm.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else {
                return []
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                guard allowedExts.contains(ext) else { continue }
                
                // Get file attributes
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                      let isDir = resourceValues.isDirectory, !isDir else {
                    continue
                }
                
                let size = Int64(resourceValues.fileSize ?? 0)
                let metadata = ImageManager.shared.getMetadata(for: fileURL)
                
                let photo = PhotoItem(
                    url: fileURL,
                    fileSize: size,
                    creationDate: metadata.creationDate,
                    cameraModel: metadata.cameraModel
                )
                items.append(photo)
            }
            return items
        }.value
    }
    
    private func countFilesInDirectory(_ url: URL) -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        return files.filter { fileURL in
            let ext = fileURL.pathExtension.lowercased()
            let isPhoto = PhotosViewModel.allowedExtensions.contains(ext)
            
            var isDir = false
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]) {
                isDir = resourceValues.isDirectory ?? false
            }
            
            return isPhoto && !isDir
        }.count
    }
    
    public func refreshSourceDirectory() {
        if let source = sourceDirectory {
            loadSourceDirectory(url: source)
        }
        
        // Refresh counts of targets
        for i in 0..<targetFolders.count {
            targetFolders[i].filesCount = countFilesInDirectory(targetFolders[i].url)
        }
    }
    
    // MARK: - Sort Photos
    
    private func sortPhotos() {
        switch sortOrder {
        case .name:
            photos.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .date:
            photos.sort { $0.creationDate < $1.creationDate }
        case .size:
            photos.sort { $0.fileSize < $1.fileSize }
        }
    }
    
    // MARK: - Selection Helpers
    
    public func selectAll() {
        selectedPhotoIDs = Set(photos.map { $0.id })
    }
    
    public func clearSelection() {
        selectedPhotoIDs.removeAll()
    }
    
    public func toggleSelection(for id: UUID) {
        if selectedPhotoIDs.contains(id) {
            selectedPhotoIDs.remove(id)
        } else {
            selectedPhotoIDs.insert(id)
        }
    }
    
    public func selectRange(from startID: UUID, to endID: UUID) {
        guard let startIndex = photos.firstIndex(where: { $0.id == startID }),
              let endIndex = photos.firstIndex(where: { $0.id == endID }) else {
            return
        }
        
        let rangeStart = min(startIndex, endIndex)
        let rangeEnd = max(startIndex, endIndex)
        
        for i in rangeStart...rangeEnd {
            selectedPhotoIDs.insert(photos[i].id)
        }
    }
    
    // MARK: - Target Folders
    
    public func addTargetFolder(url: URL) {
        logDebug("addTargetFolder: Adding target: \(url.path)")
        print("addTargetFolder: Adding target: \(url.path)")
        // Check if already exists in list
        if targetFolders.contains(where: { $0.url.path == url.path }) {
            self.statusMessage = "Folder already added to targets."
            logDebug("addTargetFolder: Folder already in targets: \(url.path)")
            print("addTargetFolder: Folder already in targets: \(url.path)")
            return
        }
        
        let count = countFilesInDirectory(url)
        let newTarget = TargetFolder(url: url, filesCount: count)
        logDebug("addTargetFolder: Appending newTarget to targetFolders. Name: \(newTarget.name), Count: \(newTarget.filesCount)")
        targetFolders.append(newTarget)
        saveSession()
        self.statusMessage = "Added target folder: \(url.lastPathComponent)"
        logDebug("addTargetFolder: Finished adding target. targetFolders count: \(targetFolders.count)")
        print("addTargetFolder: Finished adding target. targetFolders count: \(targetFolders.count)")
    }
    
    public func createNewTargetFolder(named name: String) {
        logDebug("createNewTargetFolder: Creating subfolder: \(name)")
        guard let source = sourceDirectory else {
            self.statusMessage = "Select a source directory first."
            logDebug("createNewTargetFolder: FAILED - sourceDirectory is nil")
            return
        }
        
        let targetURL = source.appendingPathComponent(name, isDirectory: true)
        logDebug("createNewTargetFolder: targetURL path: \(targetURL.path)")
        
        do {
            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
            logDebug("createNewTargetFolder: Successfully created directory on disk: \(targetURL.path)")
            addTargetFolder(url: targetURL)
            self.statusMessage = "Created and added target folder: \(name)"
        } catch {
            self.statusMessage = "Failed to create folder: \(error.localizedDescription)"
            logDebug("createNewTargetFolder: FAILED to create directory: \(error.localizedDescription)")
        }
    }
    
    public func removeTargetFolder(at indexSet: IndexSet) {
        logDebug("removeTargetFolder: Removing targets at indexSet: \(indexSet)")
        targetFolders.remove(atOffsets: indexSet)
        saveSession()
    }
    
    // MARK: - Moving Files & Undo
    
    public func initiateMove(to target: TargetFolder) {
        guard !selectedPhotoIDs.isEmpty else {
            self.statusMessage = "No photos selected to move."
            return
        }
        
        if selectedPhotoIDs.count > 50 {
            self.pendingTargetFolder = target
            self.showMoveConfirmation = true
        } else {
            executeMove(to: target)
        }
    }
    
    public func executeMove(to target: TargetFolder) {
        self.isLoading = true
        let selectedPhotos = photos.filter { selectedPhotoIDs.contains($0.id) }
        
        Task {
            let movedItems = await moveFilesAsync(photos: selectedPhotos, to: target.url)
            
            await MainActor.run {
                if !movedItems.isEmpty {
                    // Push to undo stack
                    let undoAction = UndoAction(movedItems: movedItems)
                    self.undoStack.append(undoAction)
                    
                    // Remove from list
                    let movedURLs = Set(movedItems.map { $0.sourceURL })
                    self.photos.removeAll { movedURLs.contains($0.url) }
                    self.selectedPhotoIDs.removeAll()
                    
                    // Update target folder count
                    if let index = self.targetFolders.firstIndex(where: { $0.id == target.id }) {
                        self.targetFolders[index].filesCount += movedItems.count
                    }
                    
                    self.statusMessage = "Moved \(movedItems.count) photos to \(target.name)."
                } else {
                    self.statusMessage = "Failed to move photos."
                }
                self.isLoading = false
            }
        }
    }
    
    private func moveFilesAsync(photos: [PhotoItem], to targetDirectory: URL) async -> [MovedItem] {
        return await Task.detached(priority: .userInitiated) { () -> [MovedItem] in
            var moved: [MovedItem] = []
            let fm = FileManager.default
            
            for photo in photos {
                let source = photo.url
                var destination = targetDirectory.appendingPathComponent(photo.filename)
                
                // Handle duplicate filenames at destination
                var counter = 1
                let baseName = source.deletingPathExtension().lastPathComponent
                let pathExtension = source.pathExtension
                
                while (try? destination.checkResourceIsReachable()) == true {
                    let newName = "\(baseName)_\(counter).\(pathExtension)"
                    destination = targetDirectory.appendingPathComponent(newName)
                    counter += 1
                }
                
                do {
                    try fm.moveItem(at: source, to: destination)
                    moved.append(MovedItem(sourceURL: source, destinationURL: destination))
                } catch {
                    print("Error moving file \(source.lastPathComponent): \(error)")
                }
            }
            
            return moved
        }.value
    }
    
    public func undoLastMove() {
        guard let lastAction = undoStack.popLast() else {
            self.statusMessage = "Nothing to undo."
            return
        }
        
        self.isLoading = true
        self.statusMessage = "Undoing last move..."
        
        Task {
            let restored = await undoFilesAsync(movedItems: lastAction.movedItems)
            
            await MainActor.run {
                // Re-add to photos list
                for item in restored {
                    // Check if file size and metadata are fetchable
                    if let attrs = try? self.fileManager.attributesOfItem(atPath: item.path) {
                        let size = attrs[.size] as? Int64 ?? 0
                        let metadata = ImageManager.shared.getMetadata(for: item)
                        let photo = PhotoItem(
                            url: item,
                            fileSize: size,
                            creationDate: metadata.creationDate,
                            cameraModel: metadata.cameraModel
                        )
                        // Avoid duplicates
                        if !self.photos.contains(where: { $0.url.path == photo.url.path }) {
                            self.photos.append(photo)
                        }
                    }
                }
                
                self.sortPhotos()
                
                // Recount files for target folders
                for i in 0..<self.targetFolders.count {
                    self.targetFolders[i].filesCount = self.countFilesInDirectory(self.targetFolders[i].url)
                }
                
                self.statusMessage = "Restored \(restored.count) photos."
                self.isLoading = false
            }
        }
    }
    
    private func undoFilesAsync(movedItems: [MovedItem]) async -> [URL] {
        return await Task.detached(priority: .userInitiated) { () -> [URL] in
            var restored: [URL] = []
            let fm = FileManager.default
            
            // Undo in reverse order
            for item in movedItems.reversed() {
                let source = item.destinationURL
                let destination = item.sourceURL
                
                if (try? source.checkResourceIsReachable()) == true {
                    do {
                        // Ensure source parent directory exists (just in case)
                        let parent = destination.deletingLastPathComponent()
                        try fm.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
                        
                        try fm.moveItem(at: source, to: destination)
                        restored.append(destination)
                    } catch {
                        print("Error restoring file \(source.lastPathComponent): \(error)")
                    }
                }
            }
            
            return restored
        }.value
    }
    
    private func logDebug(_ message: String) {
        let logURL = URL(fileURLWithPath: "/Users/kaerith/workspace/Photos/photosorter_debug.log")
        let logLine = "[\(Date())] \(message)\n"
        if let data = logLine.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
