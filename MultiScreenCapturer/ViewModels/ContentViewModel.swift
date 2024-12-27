import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var screenshots: [Screenshot] = []
    @Published var hideWindowBeforeCapture = false
    @Published var isCapturing = false
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Published var isDeletingScreenshot = false
    @Published var captureLoadingOpacity: Double = 0
    @Published var newScreenshotID: UUID?
    @Published var processingCapture = false
    
    @AppStorage("cornerStyle") private var cornerStyle = ScreenCornerStyle.none
    @AppStorage("screenSpacing") private var screenSpacing: Double = 10
    @AppStorage("enableShadow") private var enableShadow = true
    @AppStorage("resolutionStyle") private var resolutionStyle = ResolutionStyle.highestDPI
    @AppStorage("cornerRadius") private var cornerRadius: Double = 30
    @AppStorage("copyToClipboard") private var copyToClipboard = false
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = false
    @AppStorage("autoSavePath") private var autoSavePath = ""
    
    func setupView() {
        loadScreenshots()
    }
    
    func captureScreens(selectedScreenshot: Binding<Screenshot?>, showingMainView: Binding<Bool>) {
        isCapturing = true
        
        if hideWindowBeforeCapture {
            NSApp.mainWindow?.miniaturize(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performCapture(selectedScreenshot: selectedScreenshot, showingMainView: showingMainView)
            }
        } else {
            performCapture(selectedScreenshot: selectedScreenshot, showingMainView: showingMainView)
        }
    }
    
    private func performCapture(selectedScreenshot: Binding<Screenshot?>, showingMainView: Binding<Bool>) {
        processingCapture = true
        
        Task { [self] in
            let settings = CaptureSettings(
                cornerStyle: cornerStyle,
                cornerRadius: cornerRadius,
                screenSpacing: Int(screenSpacing),
                enableShadow: enableShadow,
                resolutionStyle: resolutionStyle,
                copyToClipboard: copyToClipboard,
                autoSaveToPath: autoSaveEnabled ? autoSavePath : nil
            )
            
            let screenshot = await Task.detached {
                return ScreenCapturer.captureAllScreens(with: settings)
            }.value
            
            guard let screenshot = screenshot else {
                await MainActor.run { 
                    processingCapture = false
                    isCapturing = false
                }
                return
            }
            
            // Save to sandbox on background thread
            let saved = await Task.detached {
                return ScreenCapturer.saveToSandbox(screenshot)
            }.value
            
            guard let saved = saved else {
                await MainActor.run { processingCapture = false }
                return
            }
            
            // Handle clipboard on background thread if needed
            if settings.copyToClipboard {
                await Task.detached {
                    if let pngData = try? Data(contentsOf: URL(fileURLWithPath: saved.filepath)),
                       let image = NSImage(data: pngData) {
                        ScreenCapturer.copyToClipboard(image)
                    }
                }.value
            }
            
            // Handle auto-save on background thread if needed
            if let path = settings.autoSaveToPath {
                await Task.detached {
                    ScreenCapturer.saveToPath(screenshot, path: path)
                }.value
            }
            
            // Update UI on main thread
            await MainActor.run { [self] in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.screenshots.insert(saved, at: 0)
                    self.newScreenshotID = saved.id
                    selectedScreenshot.wrappedValue = saved
                    showingMainView.wrappedValue = false
                    self.captureLoadingOpacity = 0
                }
                
                // Fade in the new screenshot
                withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
                    self.captureLoadingOpacity = 1
                }
                
                // Reset animation states after longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                    self.newScreenshotID = nil
                }
                
                self.processingCapture = false
                self.isCapturing = false
            }
        }
    }
    
    func shareScreenshot(_ screenshot: Screenshot?) {
        guard let screenshot = screenshot else { return }
        let fileURL = URL(fileURLWithPath: screenshot.filepath)
        let picker = NSSharingServicePicker(items: [fileURL])
        if let contentView = NSApp.windows.first?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
    
    func saveScreenshot(_ screenshot: Screenshot?) async {
        guard let screenshot = screenshot,
              let image = await ScreenCapturer.loadImage(from: screenshot.filepath) else {
            return
        }
        
        ScreenCapturer.saveScreenshot(image)
    }
    
    func deleteSelectedScreenshot(_ screenshot: Screenshot?, selectedScreenshot: Binding<Screenshot?>, showingMainView: Binding<Bool>) {
        guard let screenshot = screenshot else { return }
        
        isDeletingScreenshot = true
        
        let currentIndex = screenshots.firstIndex(where: { $0.id == screenshot.id })
        let nextScreenshot = currentIndex.map { idx in
            (idx + 1 < screenshots.count) ? screenshots[idx + 1] : 
            (idx > 0 ? screenshots[idx - 1] : nil)
        }
        
        selectedScreenshot.wrappedValue = nextScreenshot ?? nil
        showingMainView.wrappedValue = nextScreenshot == nil
        
        Task {
            try? await Task.detached {
                try FileManager.default.removeItem(atPath: screenshot.filepath)
            }.value
            
            await MainActor.run {
                if let index = screenshots.firstIndex(where: { $0.id == screenshot.id }) {
                    screenshots.remove(at: index)
                }
                isDeletingScreenshot = false
            }
        }
    }
    
    private func loadScreenshots() {
        Task {
            let loadedScreenshots = await Task.detached {
                return Screenshot.loadAllScreenshots()
            }.value
            
            await MainActor.run {
                screenshots = loadedScreenshots
            }
        }
    }
}
