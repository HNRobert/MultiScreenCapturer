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
    @State private var isChangingView = false
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
            screenshotListView
                .frame(minWidth: 180)
        } detail: {
            detailView
        }
        .onAppear {
            ScreenCapturer.checkScreenCapturePermission()
            loadScreenshots()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateWindowTitle()
            }
        }
        .onChange(of: selectedScreenshot) { _, _ in
            withAnimation {
                showingMainView = false
            }
            DispatchQueue.main.async {
                updateWindowTitle()
            }
        }
        .onChange(of: showingMainView) { _, newValue in
            if newValue {
                DispatchQueue.main.async {
                    updateWindowTitle()
                }
            }
        }
        .onChange(of: columnVisibility) { _, _ in
            updateWindowTitle()
        }
    }
    
    private struct ScreenshotRow: View {
        let screenshot: Screenshot
        let newScreenshotID: UUID?
        let captureLoadingOpacity: Double
        
        var body: some View {
            NavigationLink(value: screenshot) {
                VStack(spacing: 8) {
                    if let thumbnail = ScreenCapturer.loadThumbnail(from: screenshot.filepath) {
                        GeometryReader { geometry in
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width - 20)
                                .frame(maxHeight: 120)
                                .cornerRadius(5)
                        }
                        .frame(height: 120)
                        .opacity(screenshot.id == newScreenshotID ? captureLoadingOpacity : 1)
                    }
                    Text(screenshot.displayName)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .id(screenshot.id)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
    
    private var captureButton: some View {
        Button(action: captureScreens) {
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
    
    private var screenshotListView: some View {
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
                    captureButton
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
    
    private var detailView: some View {
        Group {
            if showingMainView {
                mainView
                    .transition(.opacity)
            } else if let screenshot = selectedScreenshot {
                ScreenshotPreviewView(screenshot: screenshot)
                    .transition(.opacity)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: { showingMainView = true }) {
                                Label("Main Page", systemImage: "house")
                            }
                        }
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: deleteSelectedScreenshot) {
                                if isDeletingScreenshot {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Delete", systemImage: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .disabled(isDeletingScreenshot)
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: saveScreenshot) {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: shareScreenshot) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showingMainView)
    }
    
    private var cornerStyleOptions: [ScreenCornerStyle] {
        [.none, .mainOnly, .builtInOnly, .builtInTopOnly, .all]
    }
    
    private var resolutionStyleOptions: [ResolutionStyle] {
        [._1080p, ._2k, ._4k, .highestDPI]
    }
    
    private var captureSettingsGroup: some View {
        GroupBox("Capture Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide window before capture", isOn: $hideWindowBeforeCapture)
                Toggle("Enable Screen Shadow", isOn: $enableShadow)
                
                HStack {
                    Text("Screen Spacing")
                    TextField("Pixels", value: $screenSpacing, format: .number)
                        .frame(width: 80)
                    Text("px")
                }
                
                Picker("Screen Corners", selection: $cornerStyle) {
                    ForEach(cornerStyleOptions, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                if cornerStyle != .none {
                    HStack {
                        Text("Corner Radius")
                        TextField("Pixels", value: $cornerRadius, format: .number)
                            .frame(width: 80)
                        Text("px")
                    }
                }
                
                Picker("Resolution", selection: $resolutionStyle) {
                    ForEach(resolutionStyleOptions, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var saveSettingsGroup: some View {
        GroupBox("Save Settings") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Copy to Clipboard after Capture", isOn: $copyToClipboard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Toggle("Auto Save to Path", isOn: $autoSaveEnabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if autoSaveEnabled {
                    HStack(spacing: 8) {
                        TextField("Save Path", text: $autoSavePath)
                        Button("Browse") {
                            selectSavePath()
                        }
                        .frame(width: 80)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 20) {
                        captureSettingsGroup
                        saveSettingsGroup
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)
            
            Button(action: captureScreens) {
                Text("Capture All Screens")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .disabled(isCapturing)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 440, maxWidth: .infinity)
        .scrollIndicators(.visible)
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
                await MainActor.run { processingCapture = false }
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
    
    private func saveScreenshot() {
        guard let screenshot = selectedScreenshot,
              let image = ScreenCapturer.loadImage(from: screenshot.filepath) else { return }
        
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
