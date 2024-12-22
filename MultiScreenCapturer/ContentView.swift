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
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedScreenshot) {
                ForEach(screenshots) { screenshot in
                    NavigationLink(value: screenshot) {
                        Label(screenshot.timestamp.formatted(), systemImage: "photo")
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
        } detail: {
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
        .onAppear {
            ScreenCapturer.checkScreenCapturePermission()
        }
        .onChange(of: selectedScreenshot) { _, _ in
            showingMainView = false
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 20) {
            Toggle("Hide window before capture", isOn: $hideWindowBeforeCapture)
                .padding()
            
            Button(action: captureScreens) {
                Text("Capture All Screens")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isCapturing)
        }
        .frame(width: 300, height: 150)
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
        if let screenshot = ScreenCapturer.captureAllScreens(),
           let saved = ScreenCapturer.saveToSandbox(screenshot, context: modelContext) {
            selectedScreenshot = saved
            showingMainView = false
        }
        
        if hideWindowBeforeCapture {
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        }
        
        isCapturing = false
    }
    
    private func shareScreenshot() {
        guard let screenshot = selectedScreenshot,
              let image = ScreenCapturer.loadImage(from: screenshot.filepath) else { return }
        
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: .zero, of: NSApp.windows.first?.contentView as! NSView, preferredEdge: .minY)
    }
    
    private func saveScreenshot() {
        guard let screenshot = selectedScreenshot,
              let image = ScreenCapturer.loadImage(from: screenshot.filepath) else { return }
        
        ScreenCapturer.saveScreenshot(image)
    }
    
    private func deleteSelectedScreenshot() {
        if let screenshot = selectedScreenshot,
           let currentIndex = screenshots.firstIndex(where: { $0.id == screenshot.id }) {
            
            // 确定下一个要选择的截图
            let nextScreenshot: Screenshot?
            if currentIndex + 1 < screenshots.count {
                // 有更老的图片，选择它
                nextScreenshot = screenshots[currentIndex + 1]
            } else if currentIndex > 0 {
                // 没有更老的，但有更新的图片
                nextScreenshot = screenshots[currentIndex - 1]
            } else {
                // 这是唯一的图片
                nextScreenshot = nil
            }
            
            // 删除当前截图
            try? FileManager.default.removeItem(atPath: screenshot.filepath)
            modelContext.delete(screenshot)
            
            // 更新选择
            selectedScreenshot = nextScreenshot
            showingMainView = nextScreenshot == nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
