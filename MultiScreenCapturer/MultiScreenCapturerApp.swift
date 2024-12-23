//
//  MultiScreenCapturerApp.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftData
import SwiftUI

@main
struct MultiScreenCapturerApp: App {
    @State private var windowTitle = "MultiScreen Capturer"
    let container: ModelContainer

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
}
