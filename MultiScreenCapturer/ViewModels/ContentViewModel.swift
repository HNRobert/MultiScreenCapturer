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
    @Published private var wasWindowHidden = false
    @Published var isLoadingScreenshots = true
    
    @AppStorage("cornerStyle") private var cornerStyle = ScreenCornerStyle.none
    @AppStorage("screenSpacing") private var screenSpacing: Double = 10
    @AppStorage("enableShadow") private var enableShadow = true
    @AppStorage("resolutionStyle") private var resolutionStyle = ResolutionStyle.highestDPI
    @AppStorage("cornerRadius") private var cornerRadius: Double = 30
    @AppStorage("copyToClipboard") private var copyToClipboard = false
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = false
    @AppStorage("autoSavePath") private var autoSavePath = ""
    
    func setupView() {
        isLoadingScreenshots = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let loadedScreenshots = Screenshot.loadAllScreenshots()
            
            for screenshot in loadedScreenshots {
                _ = ScreenCapturer.loadThumbnail(from: screenshot.filepath)
            }
            
            await MainActor.run {
                self?.screenshots = loadedScreenshots
                self?.isLoadingScreenshots = false
            }
        }
    }
    
    func captureScreens(selectedScreenshot: Binding<Screenshot?>, showingMainView: Binding<Bool>) {
        isCapturing = true
        wasWindowHidden = false
        performCapture(selectedScreenshot: selectedScreenshot, showingMainView: showingMainView)
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
                hideWindowBeforeCapture: hideWindowBeforeCapture,
                mainWindow: NSApp.mainWindow,
                autoSaveEnabled: autoSaveEnabled,
                autoSavePath: autoSavePath
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
            
            // Update UI on main thread
            await MainActor.run { [self] in
                updateUIAfterCapture(
                    screenshot,
                    selectedScreenshot: selectedScreenshot,
                    showingMainView: showingMainView
                )
            }
        }
    }
    
    private func updateUIAfterCapture(_ screenshot: Screenshot, selectedScreenshot: Binding<Screenshot?>, showingMainView: Binding<Bool>) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.screenshots.insert(screenshot, at: 0)
            self.newScreenshotID = screenshot.id
            selectedScreenshot.wrappedValue = screenshot
            showingMainView.wrappedValue = false
            self.captureLoadingOpacity = 0
        }
        
        withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
            self.captureLoadingOpacity = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.newScreenshotID = nil
        }
        
        if wasWindowHidden {
            DispatchQueue.main.async {
                if let window = NSApp.mainWindow {
                    window.deminiaturize(nil)
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            wasWindowHidden = false
        }
        
        self.processingCapture = false
        self.isCapturing = false
    }
    
    func shareScreenshot(_ screenshot: Screenshot?) {
        guard let screenshot = screenshot else { return }
        let fileURL = URL(fileURLWithPath: screenshot.filepath)
        let picker = NSSharingServicePicker(items: [fileURL])
        if let contentView = NSApp.windows.first?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
    
    private func showSaveOptions(_ screenshot: Screenshot) {
        guard let metadata = screenshot.metadata else { return }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Save as Single Image", action: #selector(NSApp.sendAction(_:to:from:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Save as Separate Images", action: #selector(NSApp.sendAction(_:to:from:)), keyEquivalent: ""))
        
        let items = menu.items
        items[0].target = self
        items[0].action = #selector(saveSingleImage(_:))
        items[0].representedObject = screenshot
        
        items[1].target = self
        items[1].action = #selector(saveSeparateImages(_:))
        items[1].representedObject = screenshot
        
        if let view = NSApp.mainWindow?.contentView {
            let point = NSPoint(x: view.frame.width/2, y: view.frame.height/2)
            menu.popUp(positioning: nil, at: point, in: view)
        }
    }
    
    @objc private func saveSingleImage(_ sender: NSMenuItem) {
        guard let screenshot = sender.representedObject as? Screenshot else { return }
        Task {
            await saveScreenshot(screenshot)
        }
    }
    
    @objc private func saveSeparateImages(_ sender: NSMenuItem) {
        guard let screenshot = sender.representedObject as? Screenshot,
              let metadata = screenshot.metadata else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Save Location"
        
        panel.begin { response in
            guard response == .OK,
                  let url = panel.url else { return }
            
            for (index, position) in metadata.screenPositions.enumerated() {
                guard let screenImage = ScreenCapturer.extractScreenImage(screenshot, screenPosition: position) else { continue }
                
                let filename = "screen\(index + 1)_\((screenshot.filepath as NSString).lastPathComponent)"
                let fileURL = url.appendingPathComponent(filename)
                
                if let pngData = ScreenCapturer.convertToPNGData(screenImage) {
                    try? pngData.write(to: fileURL)
                }
            }
        }
    }
    
    func saveScreenshot(_ screenshot: Screenshot?) async {
        guard let screenshot = screenshot else { 
            // Show error message
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Failed to save screenshot"
                alert.informativeText = "Screenshot not found"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        showSaveOptions(screenshot)
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
}
