import SwiftUI
import AppKit

@main
struct PhotosApp: App {
    @StateObject private var viewModel = PhotosViewModel()
    
    init() {
        // Ensure that the application runs in active mode (shows in dock, menu bar, and receives focus)
        // even when launched directly as an executable during testing.
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Bring to front
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
                .frame(minWidth: 950, minHeight: 650)
                .navigationTitle(viewModel.sourceDirectory?.lastPathComponent ?? "Photo Sorter")
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
