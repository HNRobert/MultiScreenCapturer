import SwiftUI

struct ScreenshotRow: View {
    let screenshot: Screenshot
    let newScreenshotID: UUID?
    let captureLoadingOpacity: Double
    @State private var thumbnailProvider: ImageProvider?
    
    var body: some View {
        NavigationLink(value: screenshot) {
            VStack(spacing: 8) {
                if let provider = thumbnailProvider {
                    GeometryReader { geometry in
                        provider.image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width - 20)
                            .frame(maxHeight: 120)
                            .cornerRadius(5)
                    }
                    .frame(height: 120)
                    .opacity(screenshot.id == newScreenshotID ? captureLoadingOpacity : 1)
                }
                Text(screenshot.displayName)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .id(screenshot.id)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .onAppear {
            if let thumbnail = ScreenCapturer.loadThumbnail(from: screenshot.filepath) {
                thumbnailProvider = ImageProvider(nsImage: thumbnail)
            }
        }
    }
}

private struct ImageProvider {
    let image: Image
    
    init(nsImage: NSImage) {
        self.image = Image(nsImage: nsImage)
    }
}
