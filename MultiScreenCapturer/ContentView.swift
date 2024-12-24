//
//  ContentView.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var screenshots: [Screenshot] = []
    @State private var hideWindowBeforeCapture = false
    @State private var isCapturing = false
    @State private var selectedScreenshot: Screenshot?
    @State private var showingMainView = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var isDeletingScreenshot = false
    @State private var captureLoadingOpacity: Double = 0
    @State private var newScreenshotID: UUID?
    @State private var processingCapture = false
    
    @AppStorage("cornerStyle") private var cornerStyle = ScreenCornerStyle.none
    @AppStorage("screenSpacing") private var screenSpacing: Double = 10
    @AppStorage("enableShadow") private var enableShadow = true
    @AppStorage("resolutionStyle") private var resolutionStyle = ResolutionStyle.highestDPI
    @AppStorage("cornerRadius") private var cornerRadius: Double = 30
    @AppStorage("copyToClipboard") private var copyToClipboard = false
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = false
    @AppStorage("autoSavePath") private var autoSavePath = ""
    
    @Environment(\.windowTitle) private var defaultWindowTitle
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ScreenshotListView(
                screenshots: screenshots,
                selectedScreenshot: $selectedScreenshot,
                newScreenshotID: newScreenshotID,
                captureLoadingOpacity: captureLoadingOpacity,
                processingCapture: processingCapture,
                onCaptureButtonTapped: captureScreens
            )
            .frame(minWidth: 180)
        } detail: {
            DetailView(
                showingMainView: $showingMainView,
                selectedScreenshot: $selectedScreenshot,
                hideWindowBeforeCapture: $hideWindowBeforeCapture,
                isCapturing: $isCapturing,
                isDeletingScreenshot: isDeletingScreenshot,
                onHomeButtonTapped: { showingMainView = true },
                onDeleteButtonTapped: deleteSelectedScreenshot,
                onSaveButtonTapped: { Task { await saveScreenshot() } },
                onShareButtonTapped: shareScreenshot,
                onCaptureButtonTapped: captureScreens
            )
        }
        .onAppear(perform: setupView)
        .onChange(of: selectedScreenshot) { oldValue, newValue in
            handleScreenshotSelection(newValue)
        }
        .onChange(of: showingMainView) { oldValue, newValue in
            handleMainViewChange(newValue)
        }
        .onChange(of: columnVisibility) { _, _ in
            updateWindowTitle()
        }
    }
    
    private func setupView() {
        ScreenCapturer.checkScreenCapturePermission()
        loadScreenshots()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateWindowTitle()
        }
    }
    
    private func handleScreenshotSelection(_ screenshot: Screenshot?) {
        withAnimation {
            showingMainView = false
        }
        DispatchQueue.main.async {
            updateWindowTitle()
        }
    }
    
    private func handleMainViewChange(_ newValue: Bool) {
        if newValue {
            DispatchQueue.main.async {
                updateWindowTitle()
            }
        }
    }

    private func selectSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            autoSavePath = panel.url?.path ?? ""
        }
    }
    
    private func captureScreens() {
        isCapturing = true
        
        if hideWindowBeforeCapture {
            NSApp.mainWindow?.miniaturize(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                performCapture()
            }
        } else {
            performCapture()
        }
    }
    
    private func performCapture() {
        processingCapture = true
        
        Task {
            let settings = CaptureSettings(
                cornerStyle: cornerStyle,
                cornerRadius: cornerRadius,
                screenSpacing: Int(screenSpacing),
                enableShadow: enableShadow,
                resolutionStyle: resolutionStyle,
                copyToClipboard: copyToClipboard,
                autoSaveToPath: autoSaveEnabled ? autoSavePath : nil
            )
            
            // Capture on background thread
            let screenshot = await Task.detached {
                return ScreenCapturer.captureAllScreens(with: settings)
            }.value
            
            guard let screenshot = screenshot else {
                await MainActor.run { 
                    processingCapture = false
                    isCapturing = false  // 添加这行，确保失败时重置状态
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
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    screenshots.insert(saved, at: 0)
                    newScreenshotID = saved.id
                    selectedScreenshot = saved
                    showingMainView = false
                    captureLoadingOpacity = 0
                }
                
                // Fade in the new screenshot
                withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
                    captureLoadingOpacity = 1
                }
                
                // Reset animation states after longer delay to ensure scroll completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    newScreenshotID = nil
                }
                
                processingCapture = false
                isCapturing = false  // 添加这行，重置捕获状态
            }
        }
    }
    
    private func shareScreenshot() {
        guard let screenshot = selectedScreenshot else { return }
        let fileURL = URL(fileURLWithPath: screenshot.filepath)
        let picker = NSSharingServicePicker(items: [fileURL])
        if let contentView = NSApp.windows.first?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
    
    private func saveScreenshot() async {
        guard let screenshot = selectedScreenshot,
              let image = await ScreenCapturer.loadImage(from: screenshot.filepath) else {
            return
        }
        
        ScreenCapturer.saveScreenshot(image)
    }
    
    private func deleteSelectedScreenshot() {
        guard let screenshot = selectedScreenshot else { return }
        
        isDeletingScreenshot = true
        
        let currentIndex = screenshots.firstIndex(where: { $0.id == screenshot.id })
        let nextScreenshot = currentIndex.map { idx in
            (idx + 1 < screenshots.count) ? screenshots[idx + 1] : 
            (idx > 0 ? screenshots[idx - 1] : nil)
        }
        
        selectedScreenshot = nextScreenshot!
        showingMainView = nextScreenshot == nil
        
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
    
    private func updateWindowTitle() {
        let title = if showingMainView {
            defaultWindowTitle
        } else if let screenshot = selectedScreenshot {
            "\(defaultWindowTitle) (\(screenshot.displayName))"
        } else {
            defaultWindowTitle
        }
        
        DispatchQueue.main.async {
            NSApp.windows.first?.title = title
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

#Preview {
    ContentView()
}
