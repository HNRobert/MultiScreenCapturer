import SwiftUI

struct PreviewToolbar: ToolbarContent {
    let onHomeButtonTapped: () -> Void
    let onDeleteButtonTapped: () -> Void
    let onSaveButtonTapped: () -> Void
    let onShareButtonTapped: () -> Void
    let isDeletingScreenshot: Bool
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: onHomeButtonTapped) {
                Label("Main Page", systemImage: "house")
            }
        }
        ToolbarItem(placement: .destructiveAction) {
            Button(action: onDeleteButtonTapped) {
                if isDeletingScreenshot {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            .disabled(isDeletingScreenshot)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: onSaveButtonTapped) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: onShareButtonTapped) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
