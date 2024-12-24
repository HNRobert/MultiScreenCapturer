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
            } else if let screenshot = selectedScreenshot {
                ScreenshotPreviewView(screenshot: screenshot)
                    .transition(.opacity)
                    .toolbar {
                        PreviewToolbar(
                            onHomeButtonTapped: onHomeButtonTapped,
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
