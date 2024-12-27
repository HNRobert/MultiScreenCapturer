import SwiftUI

struct PreviewToolbar: ToolbarContent {
    let onDeleteButtonTapped: () -> Void
    let onSaveButtonTapped: () -> Void
    let onShareButtonTapped: () -> Void
    let isDeletingScreenshot: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onDeleteButtonTapped) {
                HStack {
                    Label("Delete", systemImage: "trash")
                        .symbolEffect(.bounce, value: isDeletingScreenshot)
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(Color.red)
                }
            }
            .disabled(isDeletingScreenshot)
            Button(action: onSaveButtonTapped) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            Button(action: onShareButtonTapped) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
