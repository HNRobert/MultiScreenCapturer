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
}
