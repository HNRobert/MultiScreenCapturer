//
//  ContentView.swift
//  MultiScreenCapturer
//
//  Created by Robert He on 2024/12/22.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showingMainView = true
    @State private var selectedScreenshot: Screenshot?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
            ScreenshotListView(
                screenshots: viewModel.screenshots,
                selectedScreenshot: $selectedScreenshot,
                showingMainView: $showingMainView,
                newScreenshotID: viewModel.newScreenshotID,
                captureLoadingOpacity: viewModel.captureLoadingOpacity,
                processingCapture: viewModel.processingCapture,
                onCaptureButtonTapped: { viewModel.captureScreens(selectedScreenshot: $selectedScreenshot, showingMainView: $showingMainView) }
            )
            .frame(minWidth: 180)
            .onChange(of: selectedScreenshot) { _, newValue in
                withAnimation {
                    showingMainView = newValue == nil
                }
            }
        } detail: {
            DetailView(
                showingMainView: $showingMainView,
                selectedScreenshot: $selectedScreenshot,
                hideWindowBeforeCapture: $viewModel.hideWindowBeforeCapture,
                isCapturing: $viewModel.isCapturing,
                isDeletingScreenshot: viewModel.isDeletingScreenshot,
                onHomeButtonTapped: { showingMainView = true },
                onDeleteButtonTapped: { viewModel.deleteSelectedScreenshot(selectedScreenshot, selectedScreenshot: $selectedScreenshot, showingMainView: $showingMainView) },
                onSaveButtonTapped: { Task { await viewModel.saveScreenshot(selectedScreenshot) } },
                onShareButtonTapped: { viewModel.shareScreenshot(selectedScreenshot) },
                onCaptureButtonTapped: { viewModel.captureScreens(selectedScreenshot: $selectedScreenshot, showingMainView: $showingMainView) }
            )
        }
        .environment(\.showingMainView, showingMainView)
        .environment(\.selectedScreenshot, selectedScreenshot)
        .onAppear {
            viewModel.setupView()
        }
    }
}

#Preview {
    ContentView()
}
