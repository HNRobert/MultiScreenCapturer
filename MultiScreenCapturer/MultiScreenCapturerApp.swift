//
//  MultiScreenCapturerApp.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftUI
import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    var shouldTerminateOnClose: Bool = true
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if shouldTerminateOnClose {
            NSApplication.shared.terminate(nil)
        }
        return true
    }
}

@main
struct MultiScreenCapturerApp: App {
    private let windowDelegate = WindowDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("MultiScreen Capturer")
                .background {
                    WindowAccessor { window in
                        window.delegate = windowDelegate
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 800, height: 600)
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
