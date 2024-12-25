import Foundation

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

struct Screenshot: Identifiable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let filepath: String
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    static func loadAllScreenshots() -> [Screenshot] {
        guard let documentDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return [] }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            return fileURLs
                .filter { $0.pathExtension == "png" }
                .compactMap { url -> Screenshot? in
                    guard let timestamp = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    else { return nil }
                    
                    return Screenshot(
                        id: UUID(),
                        timestamp: timestamp,
                        filepath: url.path
                    )
                }
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Error loading screenshots: \(error)")
            return []
        }
    }
    
    static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
