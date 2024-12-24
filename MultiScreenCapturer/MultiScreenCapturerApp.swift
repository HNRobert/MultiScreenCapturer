//
//  MultiScreenCapturerApp.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

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
    private let windowDelegate = WindowDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupWindow()
                }
                .environment(\.windowTitle, windowTitle)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 800, height: 600)
    }
    
    private func setupWindow() {
        guard let window = NSApp.windows.first else { return }
        window.delegate = windowDelegate
        window.title = windowTitle
        
        // 确保窗口标题正确显示
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: window,
            queue: .main
        ) { _ in
            window.title = windowTitle
        }
    }
}
