//
//  MultiScreenCapturerApp.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftUI
import SwiftData

@main
struct MultiScreenCapturerApp: App {
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
        }
        .modelContainer(container)
    }
}
