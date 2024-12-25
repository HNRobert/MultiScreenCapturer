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
    @State private var currentScale: CGFloat = 1.0
    @State private var showResetButton: Bool = false
    @State private var previewOpacity: Double = 1.0
    @State private var isPreviewLoading = false
    @State private var currentScreenshot: Screenshot?
    
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
                ZStack {
                    QuickLookPreviewView(
                        url: URL(fileURLWithPath: screenshot.filepath),
                        isLoading: $isPreviewLoading
                    )
                    .opacity(previewOpacity)
                    
                    if isPreviewLoading {
                        LoadingOverlay()
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
                .onChange(of: screenshot) { _, newScreenshot in
                    guard currentScreenshot != newScreenshot else { return }
                    
                    // 等待前一个动画完成后再开始新的动画
                    if previewOpacity < 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            currentScreenshot = newScreenshot
                            withAnimation(.easeOut(duration: 0.2)) {
                                previewOpacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    previewOpacity = 1
                                }
                            }
                        }
                    } else {
                        currentScreenshot = newScreenshot
                        withAnimation(.easeOut(duration: 0.2)) {
                            previewOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeIn(duration: 0.2)) {
                                previewOpacity = 1
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button(action: onHomeButtonTapped) {
                            Label("Settings", systemImage: "gear")
                        }
                    }
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
        }
        .animation(.easeInOut, value: showingMainView)
    }
}
