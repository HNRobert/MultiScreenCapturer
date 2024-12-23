import SwiftUI

struct ScreenshotPreviewView: View {
    let screenshot: Screenshot
    @State private var image: NSImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentMousePosition: CGPoint = .zero
    @State private var isLoading = true
    @State private var imageOpacity: Double = 0
    
    private var isAtDefaultState: Bool {
        return scale == 1.0 && offset == .zero
    }
    
    private func scaleAround(scale: CGFloat) {
        guard let frameSize = image?.size else { return }
        
        let previousScale = self.scale
        self.scale = max(0.5, lastScale * scale)
        
        let scaleRatio = self.scale / previousScale
        let newOffset = CGSize(
            width: (offset.width + currentMousePosition.x) * scaleRatio - currentMousePosition.x,
            height: (offset.height + currentMousePosition.y) * scaleRatio - currentMousePosition.y
        )
        
        offset = newOffset
        lastOffset = newOffset
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scaleAround(scale: value)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onHover { isHovered in
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            currentMousePosition = CGPoint(
                                                x: location.x,
                                                y: location.y
                                            )
                                        case .ended:
                                            break
                                        }
                                    }
                            }
                        )
                        .opacity(imageOpacity)
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                            if !isAtDefaultState {
                                Button(action: resetView) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .padding(8)
                                }
                                .buttonStyle(.borderless)
                                .padding()
                            }
                        }
        }
        .onAppear {
            loadImageAsync()
        }
        .onChange(of: screenshot) { _, _ in
            resetView()
            withAnimation(.easeOut(duration: 0.2)) {
                imageOpacity = 0
            }
            isLoading = true
            loadImageAsync()
        }
    }
    
    private func loadImageAsync() {
        Task {
            await MainActor.run {
                isLoading = true
                imageOpacity = 0
            }
            
            // Add small delay to ensure loading indicator shows
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            let loadedImage = await Task.detached {
                return ScreenCapturer.loadImage(from: screenshot.filepath)
            }.value
            
            await MainActor.run {
                if let loadedImage = loadedImage {
                    image = loadedImage
                    isLoading = false
                    withAnimation(.easeIn(duration: 0.3)) {
                        imageOpacity = 1
                    }
                } else {
                    // 处理加载失败的情况
                    isLoading = false
                    // 可以在这里添加错误提示UI
                }
            }
        }
    }
    
    private func resetView() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}
