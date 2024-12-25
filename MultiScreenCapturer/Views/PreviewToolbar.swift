import SwiftUI

struct PreviewToolbar: ToolbarContent {
    let onDeleteButtonTapped: () -> Void
    let onSaveButtonTapped: () -> Void
    let onShareButtonTapped: () -> Void
    let isDeletingScreenshot: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onShareButtonTapped) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: onSaveButtonTapped) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            
            Button(action: onDeleteButtonTapped) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(isDeletingScreenshot)
        }
    }
}
