import SwiftUI

struct PreviewToolbar: ToolbarContent {
    let onDeleteButtonTapped: () -> Void
    let onSaveButtonTapped: () -> Void
    let onShareButtonTapped: () -> Void
    let onResetButtonTapped: () -> Void
    let isDeletingScreenshot: Bool
    let scale: CGFloat
    let showResetButton: Bool
    
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
        
        ToolbarItemGroup(placement: .principal) {
            Text("\(Int(scale * 100))%")
                .monospacedDigit()
                .frame(minWidth: 50)
            if showResetButton {
                Button(action: onResetButtonTapped) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
