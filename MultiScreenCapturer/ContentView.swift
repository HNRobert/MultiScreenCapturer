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
    @Query private var screenshots: [Screenshot]
    
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
}

#Preview {
    ContentView()
        .modelContainer(for: Screenshot.self, inMemory: true)
}
