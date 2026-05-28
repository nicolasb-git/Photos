import Foundation
import Cocoa

@main
struct TestRunner {
    static func main() async {
        print("=== Starting Core Logic Verification ===")
        
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let sourceURL = URL(fileURLWithPath: currentDir).appendingPathComponent("TestSourcePhotos")
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            print("Error: TestSourcePhotos directory does not exist. Run swift generate_test_photos.swift first.")
            exit(1)
        }
        
        do {
            try await runTests(sourceURL: sourceURL)
        } catch {
            print("FAIL: Verification failed with error: \(error)")
            exit(1)
        }
    }
    
    @MainActor
    static func runTests(sourceURL: URL) async throws {
        let fileManager = FileManager.default
        let viewModel = PhotosViewModel()
        
        // 1. Test directory loading
        print("1. Loading source directory...")
        viewModel.loadSourceDirectory(url: sourceURL)
        
        // Since loadSourceDirectory is async internally, let's wait for it to load
        while viewModel.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        print("Loaded \(viewModel.photos.count) photos.")
        assert(viewModel.photos.count == 100, "Should load 100 photos, but loaded \(viewModel.photos.count)")
        print("PASS: Loaded 100 photos successfully.")
        if let firstPhoto = viewModel.photos.first {
            print("First photo GPS - Lat: \(String(describing: firstPhoto.latitude)), Lon: \(String(describing: firstPhoto.longitude))")
        }
        
        // 2. Test sorting
        print("2. Verifying Sort Order...")
        viewModel.sortOrder = .name
        let firstByName = viewModel.photos.first?.filename ?? ""
        let lastByName = viewModel.photos.last?.filename ?? ""
        print("First by name: \(firstByName), Last: \(lastByName)")
        assert(firstByName == "MockPhoto_001.jpg", "First photo should be MockPhoto_001.jpg")
        
        viewModel.sortOrder = .date
        let firstByDate = viewModel.photos.first?.filename ?? ""
        print("First by date (newest/oldest): \(firstByDate)")
        assert(firstByDate == "MockPhoto_100.jpg", "First photo by date should be MockPhoto_100.jpg")
        print("PASS: Sorting matches expectations.")
        
        // 3. Test target folder creation
        print("3. Creating target folder...")
        let targetName = "Sorted_Vacation"
        viewModel.createNewTargetFolder(named: targetName)
        
        assert(viewModel.targetFolders.count == 1, "Should have 1 target folder")
        let target = viewModel.targetFolders[0]
        assert(target.name == targetName, "Target folder name mismatch")
        assert(target.filesCount == 0, "Target folder should be empty initially")
        
        let physicalTargetURL = sourceURL.appendingPathComponent(targetName)
        assert(fileManager.fileExists(atPath: physicalTargetURL.path), "Target folder should be created on disk")
        print("PASS: Target folder created on disk.")
        
        // 3b. Test target folder renaming
        print("3b. Renaming target folder...")
        let renamedName = "Sorted_Holiday"
        viewModel.renameTargetFolder(target, to: renamedName)
        
        assert(viewModel.targetFolders.count == 1, "Should still have 1 target folder")
        let renamedTarget = viewModel.targetFolders[0]
        assert(renamedTarget.name == renamedName, "Target folder name mismatch after rename")
        
        let physicalRenamedURL = sourceURL.appendingPathComponent(renamedName)
        assert(fileManager.fileExists(atPath: physicalRenamedURL.path), "Renamed target folder should exist on disk")
        assert(!fileManager.fileExists(atPath: physicalTargetURL.path), "Old target folder should not exist on disk")
        print("PASS: Target folder renamed on disk and in viewmodel.")
        
        // 4. Test file moving
        print("4. Selecting and moving photos...")
        // Select first 5 photos
        let selectIDs = Set(viewModel.photos.prefix(5).map { $0.id })
        viewModel.selectedPhotoIDs = selectIDs
        
        print("Selected \(viewModel.selectedPhotoIDs.count) photos.")
        viewModel.initiateMove(to: renamedTarget)
        
        // Wait for move operation
        while viewModel.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        print("Remaining photos in source: \(viewModel.photos.count)")
        assert(viewModel.photos.count == 95, "Should have 95 photos remaining")
        
        // Get updated target folder count
        let updatedTarget = viewModel.targetFolders[0]
        print("Files count in target: \(updatedTarget.filesCount)")
        assert(updatedTarget.filesCount == 5, "Target folder should report 5 files")
        
        // Verify files exist in target folder
        let filesInTargetDisk = try fileManager.contentsOfDirectory(at: physicalRenamedURL, includingPropertiesForKeys: nil)
        assert(filesInTargetDisk.count == 5, "Target directory on disk should contain 5 files")
        print("PASS: Selected photos moved successfully.")
        
        // 5. Test undo
        print("5. Undoing move...")
        viewModel.undoLastMove()
        
        // Wait for undo operation
        while viewModel.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        print("Photos count after undo: \(viewModel.photos.count)")
        assert(viewModel.photos.count == 100, "Should have returned to 100 photos")
        
        let targetAfterUndo = viewModel.targetFolders[0]
        assert(targetAfterUndo.filesCount == 0, "Target folder should be empty after undo")
        let filesInTargetDiskAfterUndo = try fileManager.contentsOfDirectory(at: physicalRenamedURL, includingPropertiesForKeys: nil)
        assert(filesInTargetDiskAfterUndo.isEmpty, "Target directory on disk should be empty after undo")
        print("PASS: Undo operation successful.")
        
        // 5b. Test folder merging
        print("5b. Testing folder merging...")
        let mergeTargetName = "Sorted_Aesthetic"
        viewModel.createNewTargetFolder(named: mergeTargetName)
        assert(viewModel.targetFolders.count == 2, "Should have 2 target folders")
        
        let folderC = viewModel.targetFolders.first(where: { $0.name == mergeTargetName })!
        let physicalFolderCURL = sourceURL.appendingPathComponent(mergeTargetName)
        
        // Move 3 photos into Sorted_Holiday
        let folderB = viewModel.targetFolders.first(where: { $0.name == renamedName })!
        viewModel.selectedPhotoIDs = Set(viewModel.photos.prefix(3).map { $0.id })
        viewModel.initiateMove(to: folderB)
        while viewModel.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        assert(viewModel.targetFolders.first(where: { $0.name == renamedName })!.filesCount == 3, "Sorted_Holiday should have 3 files")
        
        // Move 2 photos into Sorted_Aesthetic
        viewModel.selectedPhotoIDs = Set(viewModel.photos.prefix(2).map { $0.id })
        viewModel.initiateMove(to: folderC)
        while viewModel.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        assert(viewModel.targetFolders.first(where: { $0.name == mergeTargetName })!.filesCount == 2, "Sorted_Aesthetic should have 2 files")
        
        // Merge Sorted_Aesthetic (folderC) into Sorted_Holiday (folderB)
        let latestFolderB = viewModel.targetFolders.first(where: { $0.name == renamedName })!
        let latestFolderC = viewModel.targetFolders.first(where: { $0.name == mergeTargetName })!
        
        viewModel.mergeTargetFolder(latestFolderC, into: latestFolderB)
        while viewModel.isLoading {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        assert(viewModel.targetFolders.count == 1, "Should have 1 target folder after merge")
        assert(viewModel.targetFolders[0].name == renamedName, "Remaining folder should be Sorted_Holiday")
        assert(viewModel.targetFolders[0].filesCount == 5, "Sorted_Holiday filesCount should be 5 after merge")
        assert(!fileManager.fileExists(atPath: physicalFolderCURL.path), "Merged source folder should be deleted from disk")
        
        let filesInMergedFolder = try fileManager.contentsOfDirectory(at: physicalRenamedURL, includingPropertiesForKeys: nil)
        assert(filesInMergedFolder.count == 5, "Merged folder on disk should contain 5 files")
        print("PASS: Folder merging successful.")
        
        // Cleanup
        print("6. Cleaning up...")
        try fileManager.removeItem(at: physicalRenamedURL)
        print("PASS: Cleaned up target folder.")
        
        print("=== Core Logic Verification SUCCESS ===")
    }
}
