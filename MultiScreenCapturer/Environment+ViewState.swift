import SwiftUI

private struct ShowingMainViewKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct SelectedScreenshotKey: EnvironmentKey {
    static let defaultValue: Screenshot? = nil
}

extension EnvironmentValues {
    var showingMainView: Bool {
        get { self[ShowingMainViewKey.self] }
        set { self[ShowingMainViewKey.self] = newValue }
    }
    
    var selectedScreenshot: Screenshot? {
        get { self[SelectedScreenshotKey.self] }
        set { self[SelectedScreenshotKey.self] = newValue }
    }
}
