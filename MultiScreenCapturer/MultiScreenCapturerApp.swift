//
//  MultiScreenCapturerApp.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftData
import SwiftUI
import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(nil)
        return true
    }
}

@main
struct MultiScreenCapturerApp: App {
    @State private var windowTitle = "MultiScreen Capturer"
    let container: ModelContainer
    
    private let windowDelegate = WindowDelegate()
    
    init() {
        do {
            container = try ModelContainer(for: Screenshot.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupWindow()
                    NSApp.mainWindow?.title = windowTitle
                }
                .onChange(of: NSApp.mainWindow?.title) { oldTitle, newTitle in
                    if let path = NSApp.mainWindow?.representedFilename,
                        !path.isEmpty
                    {
                        let filename = (path as NSString).lastPathComponent
                        NSApp.mainWindow?.title = windowTitle + " (\(filename))"
                    } else {
                        NSApp.mainWindow?.title = windowTitle
                    }
                }
        }
        .modelContainer(container)
    }
    
    private func setupWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.delegate = windowDelegate
            }
        }
    }
}
