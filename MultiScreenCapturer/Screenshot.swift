import Foundation
import SwiftData

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
