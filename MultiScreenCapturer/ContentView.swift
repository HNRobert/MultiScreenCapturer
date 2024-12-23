//
//  ContentView.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.timestamp, order: .reverse) private var screenshots: [Screenshot]
    
    @State private var hideWindowBeforeCapture = false
    @State private var isCapturing = false
    @State private var selectedScreenshot: Screenshot?
    @State private var showingMainView = true
    
    @AppStorage("cornerStyle") private var cornerStyle = ScreenCornerStyle.none
    @AppStorage("screenSpacing") private var screenSpacing: Double = 10
    @AppStorage("enableShadow") private var enableShadow = true
    @AppStorage("resolutionStyle") private var resolutionStyle = ResolutionStyle.highestDPI
    @AppStorage("cornerRadius") private var cornerRadius: Double = 30
    
    var body: some View {
        NavigationSplitView {
            screenshotListView
        } detail: {
            detailView
        }
        .onAppear {
            ScreenCapturer.checkScreenCapturePermission()
            DispatchQueue.main.async {
                updateWindowTitle()
            }
        }
        .onChange(of: selectedScreenshot) { _, _ in
            showingMainView = false
            DispatchQueue.main.async {
                updateWindowTitle()
            }
        }
        .onChange(of: showingMainView) { _, newValue in
            if newValue {
                DispatchQueue.main.async {
                    NSApp.mainWindow?.title = "MultiScreen Capturer"
                }
            }
        }
    }
    
    private var screenshotListView: some View {
        List(selection: $selectedScreenshot) {
            ForEach(screenshots) { screenshot in
                NavigationLink(value: screenshot) {
                    VStack(spacing: 8) {
                        if let thumbnail = ScreenCapturer.loadThumbnail(from: screenshot.filepath) {
                            GeometryReader { geometry in
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width - 20) // 左右留出10px边距
                                    .frame(maxHeight: 120) // 限制最大高度
                                    .cornerRadius(5)
                            }
                            .frame(height: 120) // 固定高度确保一致性
                        }
                        Text(screenshot.displayName)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: captureScreens) {
                    Label("New Screenshot", systemImage: "plus")
                }
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if showingMainView {
                mainView
            } else if let screenshot = selectedScreenshot {
                ScreenshotPreviewView(screenshot: screenshot)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: { showingMainView = true }) {
                                Label("Main Page", systemImage: "house")
                            }
                        }
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: deleteSelectedScreenshot) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .foregroundColor(.red)
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: shareScreenshot) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: saveScreenshot) {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }
                        }
                    }
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 20) {
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
                        ForEach([ScreenCornerStyle.none,
                                .mainOnly,
                                .builtInOnly,
                                .builtInTopOnly,
                                .all], id: \.self) { style in
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
                        ForEach([ResolutionStyle._1080p,
                                ._2k,
                                ._4k,
                                .highestDPI], id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .padding()
            
            Button(action: captureScreens) {
                Text("Capture All Screens")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(10)
            }
            .disabled(isCapturing)
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 400)
        .padding()
    }
    
    private func captureScreens() {
        isCapturing = true
        
        if hideWindowBeforeCapture {
            NSApp.mainWindow?.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                performCapture()
            }
        } else {
            performCapture()
        }
    }
    
    private func performCapture() {
        let shouldRestoreWindow = hideWindowBeforeCapture
        
        let settings = CaptureSettings(
            cornerStyle: cornerStyle,
            cornerRadius: cornerRadius,
            screenSpacing: Int(screenSpacing),
            enableShadow: enableShadow,
            resolutionStyle: resolutionStyle
        )
        
        if let screenshot = ScreenCapturer.captureAllScreens(with: settings),
           let saved = ScreenCapturer.saveToSandbox(screenshot, context: modelContext) {
            selectedScreenshot = saved
            showingMainView = false
        }
        
        if shouldRestoreWindow {
            DispatchQueue.main.async {
                NSApp.mainWindow?.makeKeyAndOrderFront(nil)
            }
        }
        
        isCapturing = false
    }
    
    private func shareScreenshot() {
        guard let screenshot = selectedScreenshot,
              let image = ScreenCapturer.loadImage(from: screenshot.filepath) else { return }
        
        let picker = NSSharingServicePicker(items: [image])
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
        if let screenshot = selectedScreenshot,
           let currentIndex = screenshots.firstIndex(where: { $0.id == screenshot.id }) {
            
            // Choose the next screenshot to show
            let nextScreenshot = (currentIndex + 1 < screenshots.count) ? screenshots[currentIndex + 1] : (currentIndex > 0 ? screenshots[currentIndex - 1] : nil)
            
            // Delete the screenshot
            try? FileManager.default.removeItem(atPath: screenshot.filepath)
            modelContext.delete(screenshot)
            
            // Update the UI
            selectedScreenshot = nextScreenshot
            showingMainView = nextScreenshot == nil
        }
    }
    
    private func updateWindowTitle() {
        if let screenshot = selectedScreenshot,
           let window = NSApp.mainWindow {
            window.title = "MultiScreen Capturer (\(screenshot.displayName))"
        } else if let window = NSApp.mainWindow {
            window.title = "MultiScreen Capturer"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
