import SwiftUI

struct ScreenshotListView: View {
    let screenshots: [Screenshot]
    @Binding var selectedScreenshot: Screenshot?
    @Binding var showingMainView: Bool
    let newScreenshotID: UUID?
    let captureLoadingOpacity: Double
    let processingCapture: Bool
    let onCaptureButtonTapped: () -> Void
    
    var body: some View {
        List(screenshots, selection: $selectedScreenshot) { screenshot in
            ScreenshotRow(
                screenshot: screenshot,
                newScreenshotID: newScreenshotID,
                captureLoadingOpacity: captureLoadingOpacity
            )
        }
        .overlay {
            if screenshots.isEmpty {
                ContentUnavailableView {
                    Label("No Screenshots", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Take a screenshot to get started")
                } actions: {
                    Button("Capture Screens", action: onCaptureButtonTapped)
                        .disabled(processingCapture)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if processingCapture {
                    ProgressView()
                        .scaleEffect(0.8)
                        .controlSize(.small)
                        .transition(.opacity)
                } else {
                    Button(action: onCaptureButtonTapped) {
                        Label("Add Screenshot", systemImage: "plus")
                    }
                    .disabled(processingCapture)
                }
            }
        }
        .animation(.easeInOut, value: processingCapture)
        .onChange(of: screenshots) { _, newScreenshots in
            if newScreenshots.isEmpty {
                selectedScreenshot = nil
            }
        }
        .onChange(of: showingMainView) { _, isShowingMain in
            if isShowingMain {
                selectedScreenshot = nil
            }
        }
    }
}
