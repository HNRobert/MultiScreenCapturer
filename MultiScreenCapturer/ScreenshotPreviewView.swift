import SwiftUI

struct ScreenshotPreviewView: View {
    let screenshot: Screenshot
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            image = ScreenCapturer.loadImage(from: screenshot.filepath)
        }
    }
}
