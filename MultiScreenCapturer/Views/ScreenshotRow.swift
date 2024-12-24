import SwiftUI

struct ScreenshotRow: View {
    let screenshot: Screenshot
    let newScreenshotID: UUID?
    let captureLoadingOpacity: Double
    
    var body: some View {
        NavigationLink(value: screenshot) {
            VStack(spacing: 8) {
                if let thumbnail = ScreenCapturer.loadThumbnail(from: screenshot.filepath) {
                    GeometryReader { geometry in
                        Image(nsImage: thumbnail)
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
    }
}
