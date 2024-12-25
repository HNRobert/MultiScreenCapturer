import SwiftUI
import Quartz
import QuickLookUI

struct QuickLookPreviewView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    class Coordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
        var preview: QLPreviewView?
        var currentURL: URL?
        let parent: QuickLookPreviewView
        
        init(_ parent: QuickLookPreviewView) {
            self.parent = parent
            super.init()
        }
        
        func updatePreview(with url: URL) {
            if currentURL != url {
                currentURL = url
                parent.isLoading = true
                
                // Make sure the preview item is hidden before changing it
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = .init(name: .easeOut)
                    preview?.layer?.opacity = 0
                } completionHandler: {
                    // Clear the preview item to avoid flickering
                    self.preview?.previewItem = nil
                    
                    // Delay the preview item update to avoid flickering
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.preview?.previewItem = url as QLPreviewItem
                        
                        // Wait for the preview item to load before showing it
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NSAnimationContext.runAnimationGroup { context in
                                context.duration = 0.3
                                context.timingFunction = .init(name: .easeIn)
                                self.preview?.layer?.opacity = 1.0
                            } completionHandler: {
                                self.parent.isLoading = false
                            }
                        }
                    }
                }
            }
        }
        
        // QLPreviewPanelDataSource
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            return currentURL != nil ? 1 : 0
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            return currentURL as QLPreviewItem?
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> QLPreviewView {
        let preview = QLPreviewView()
        preview.autostarts = true
        preview.wantsLayer = true
        preview.layer?.opacity = 0  // Hide the preview item initially
        context.coordinator.preview = preview
        context.coordinator.updatePreview(with: url)
        return preview
    }
    
    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        context.coordinator.updatePreview(with: url)
    }
    
    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Coordinator) {
        coordinator.preview?.previewItem = nil
        coordinator.preview = nil
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            ProgressView()
                .scaleEffect(1.5)
                .controlSize(.large)
        }
    }
}
