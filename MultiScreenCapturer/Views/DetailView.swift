import SwiftUI

struct DetailView: View {
    @Binding var showingMainView: Bool
    @Binding var selectedScreenshot: Screenshot?
    @Binding var hideWindowBeforeCapture: Bool
    @Binding var isCapturing: Bool
    let isDeletingScreenshot: Bool
    let onHomeButtonTapped: () -> Void
    let onDeleteButtonTapped: () -> Void
    let onSaveButtonTapped: () -> Void
    let onShareButtonTapped: () -> Void
    let onCaptureButtonTapped: () -> Void
    
    var body: some View {
        Group {
            if showingMainView {
                SettingView(
                    isCapturing: $isCapturing,
                    hideWindowBeforeCapture: $hideWindowBeforeCapture,
                    captureAction: onCaptureButtonTapped
                )
                .transition(.opacity)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: onHomeButtonTapped) {
                            Label("Settings", systemImage: "gear")
                        }
                        .disabled(true)
                    }
                }
            } else if let screenshot = selectedScreenshot {
                ScreenshotPreviewView(screenshot: screenshot)
                    .transition(.opacity)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: onHomeButtonTapped) {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                        PreviewToolbar(
                            onDeleteButtonTapped: onDeleteButtonTapped,
                            onSaveButtonTapped: onSaveButtonTapped,
                            onShareButtonTapped: onShareButtonTapped,
                            isDeletingScreenshot: isDeletingScreenshot
                        )
                    }
            }
        }
        .animation(.easeInOut, value: showingMainView)
    }
}
