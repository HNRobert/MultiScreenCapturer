import SwiftUI

struct ScreenshotListView: View {
    let screenshots: [Screenshot]
    @Binding var selectedScreenshot: Screenshot?
    @Binding var showingMainView: Bool
    let newScreenshotID: UUID?
    let captureLoadingOpacity: Double
    let processingCapture: Bool
    let onCaptureButtonTapped: () -> Void
    let isLoading: Bool
    
    var body: some View {
        List(screenshots, selection: $selectedScreenshot) { screenshot in
            ScreenshotRow(
                screenshot: screenshot,
                newScreenshotID: newScreenshotID,
                captureLoadingOpacity: captureLoadingOpacity
            )
        }
        .overlay {
            EmptyStateView(
                processingCapture: processingCapture,
                isVisible: screenshots.isEmpty && !isLoading,
                onCaptureButtonTapped: onCaptureButtonTapped
            )
            
            if isLoading {
                ContentUnavailableView {
                    ProgressView()
                        .controlSize(.large)
                } description: {
                    Text("Loading Screenshots...")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                CaptureButton(
                    processingCapture: processingCapture,
                    onCaptureButtonTapped: onCaptureButtonTapped
                )
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

private struct EmptyStateView: View {
    let processingCapture: Bool
    let isVisible: Bool
    let onCaptureButtonTapped: () -> Void
    
    var body: some View {
        if isVisible {
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
}

private struct CaptureButton: View {
    let processingCapture: Bool
    let onCaptureButtonTapped: () -> Void
    
    var body: some View {
        Button(action: onCaptureButtonTapped) {
            HStack {
                Label("Delete", systemImage: processingCapture ? "circle" : "plus")
                    .symbolEffect(
                        .pulse,
                        options: processingCapture ? .repeating : .default,
                        value: processingCapture
                    )
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .disabled(processingCapture)
    }
}
