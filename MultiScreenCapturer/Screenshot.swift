import Foundation
import SwiftData

enum ScreenCornerStyle: String, Codable {
    case none = "No Corners"
    case mainOnly = "Main Screen Only"
    case builtInOnly = "Built-in Screen Only"
    case builtInTopOnly = "Built-in Screen Top Only"
    case all = "All Screens"
}

enum ResolutionStyle: String, Codable {
    case _1080p = "1080p"
    case _2k = "2K"
    case _4k = "4K"
    case highestDPI = "Highest DPI Screen"
}

@Model
final class Screenshot {
    var id: UUID
    var timestamp: Date
    var filepath: String
    
    init(id: UUID = UUID(), timestamp: Date = Date(), filepath: String) {
        self.id = id
        self.timestamp = timestamp
        self.filepath = filepath
    }
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
