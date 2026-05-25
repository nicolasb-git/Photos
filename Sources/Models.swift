import Foundation

public struct PhotoItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let filename: String
    public let fileSize: Int64
    public let creationDate: Date
    public let creationDateString: String
    public let cameraModel: String?
    
    public init(id: UUID = UUID(), url: URL, fileSize: Int64, creationDate: Date, cameraModel: String? = nil) {
        self.id = id
        self.url = url
        self.filename = url.lastPathComponent
        self.fileSize = fileSize
        self.creationDate = creationDate
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        self.creationDateString = formatter.string(from: creationDate)
        
        self.cameraModel = cameraModel
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct TargetFolder: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public var filesCount: Int
    
    public init(id: UUID = UUID(), url: URL, filesCount: Int = 0) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
        self.filesCount = filesCount
    }
}

public struct MovedItem: Hashable, Sendable {
    public let sourceURL: URL
    public let destinationURL: URL
}

public struct UndoAction: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let movedItems: [MovedItem]
    
    public init(id: UUID = UUID(), movedItems: [MovedItem]) {
        self.id = id
        self.timestamp = Date()
        self.movedItems = movedItems
    }
}

public enum PhotoSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    
    public var id: String { self.rawValue }
}
