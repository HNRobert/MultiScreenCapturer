import SwiftUI

private struct WindowTitleKey: EnvironmentKey {
    static let defaultValue: String = "MultiScreen Capturer"
}

extension EnvironmentValues {
    var windowTitle: String {
        get { self[WindowTitleKey.self] }
        set { self[WindowTitleKey.self] = newValue }
    }
}
