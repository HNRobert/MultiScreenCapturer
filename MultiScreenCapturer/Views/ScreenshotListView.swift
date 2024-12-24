import SwiftUI

struct ScreenshotListView: View {
    let screenshots: [Screenshot]
    @Binding var selectedScreenshot: Screenshot?
    let newScreenshotID: UUID?
    let captureLoadingOpacity: Double
    let processingCapture: Bool
    let onCaptureButtonTapped: () -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedScreenshot) {
                ForEach(screenshots) { screenshot in
                    ScreenshotRow(
                        screenshot: screenshot,
                        newScreenshotID: newScreenshotID,
                        captureLoadingOpacity: captureLoadingOpacity
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onCaptureButtonTapped) {
                        if processingCapture {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                        } else {
                            Label("New Screenshot", systemImage: "plus")
                        }
                    }
                    .disabled(processingCapture)
                }
            }
            .onChange(of: newScreenshotID) { _, id in
                if let id = id {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
    }
}
