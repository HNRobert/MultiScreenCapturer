import SwiftUI
import Cocoa

extension NSImage: @unchecked @retroactive Sendable {}

struct ScreenshotPreviewView: View {
    let screenshot: Screenshot
    @Environment(\.showingMainView) private var showingMainView
    @Environment(\.selectedScreenshot) private var selectedScreenshot
    @State private var imageProvider: ImageProvider?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentMousePosition: CGPoint = .zero
    @State private var isLoading = true
    @State private var imageOpacity: Double = 0
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var viewSize: CGSize = .zero
    @State private var contentSize: CGSize = .zero
    @GestureState private var isDragging: Bool = false
    
    private var isAtDefaultState: Bool {
        return scale == 1.0 && offset == .zero
    }
    
    private func scaleAround(scale: CGFloat) {
        let previousScale = self.scale
        self.scale = max(0.5, lastScale * scale)
        
        let mousePoint = NSPoint(x: currentMousePosition.x, y: currentMousePosition.y)
        print("Zooming around point: \(mousePoint), scale: \(self.scale)")
        
        // Calculate new offset based on scale change
        let scaleChange = self.scale / previousScale
        offset = CGSize(
            width: offset.width * scaleChange,
            height: offset.height * scaleChange
        )
        lastOffset = offset
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                lastOffset = offset
            }
    }
    
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scaleAround(scale: value)
                }
                .onEnded { _ in
                    lastScale = scale
                },
            dragGesture
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let provider = imageProvider {
                    ScrollView([.horizontal, .vertical]) {
                        provider.image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: viewSize.width, height: viewSize.height)
                            .frame(
                                width: max(viewSize.width * scale, viewSize.width),
                                height: max(viewSize.height * scale, viewSize.height)
                            )
                            .overlay(
                                GeometryReader { geo in
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onContinuousHover { phase in
                                            switch phase {
                                            case .active(let location):
                                                if !isDragging {
                                                    currentMousePosition = CGPoint(
                                                        x: location.x,
                                                        y: location.y
                                                    )
                                                    print("Current Mouse Point: \(currentMousePosition.x), \(currentMousePosition.y)")
                                                }
                                            case .ended:
                                                break
                                            }
                                        }
                                }
                            )
                            .gesture(combinedGesture)
                    }
                    .opacity(imageOpacity)
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
//                GeometryReader { geo in
//                    Color.clear
//                        .contentShape(Rectangle())
//                        .onContinuousHover { phase in
//                            switch phase {
//                            case .active(let location):
//                                if !isDragging {
//                                    currentMousePosition = CGPoint(
//                                        x: location.x,
//                                        y: location.y
//                                    )
//                                    print("Current Mouse Point: \(currentMousePosition.x), \(currentMousePosition.y)")
//                                }
//                            case .ended:
//                                break
//                            }
//                        }
//                }
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
            .onPreferenceChange(ContentSizePreferenceKey.self) { size in
                contentSize = size
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        viewSize = geo.size
                    }
                }
            )
        }
        // 添加初始布局逻辑
        .onAppear {
            loadImageAsync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resetView()
            }
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
            
            if let nsImage = await ScreenCapturer.loadImage(from: screenshot.filepath) {
                await MainActor.run {
                    imageProvider = ImageProvider(nsImage: nsImage)
                    isLoading = false
                    withAnimation(.easeIn(duration: 0.3)) {
                        imageOpacity = 1
                    }
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func resetView() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // 计算适合视图大小的初始缩放比例
            if let provider = imageProvider {
                let imageSize = provider.nsImage.size
                let viewAspect = viewSize.width / viewSize.height
                let imageAspect = imageSize.width / imageSize.height
                
                if imageAspect > viewAspect {
                    scale = viewSize.width / imageSize.width
                } else {
                    scale = viewSize.height / imageSize.height
                }
                lastScale = scale
            } else {
                scale = 1.0
                lastScale = 1.0
            }
            offset = .zero
            lastOffset = .zero
        }
    }
}

// Helper to bridge NSImage to SwiftUI Image
private struct ImageProvider {
    let image: Image
    let nsImage: NSImage
    
    init(nsImage: NSImage) {
        self.image = Image(nsImage: nsImage)
        self.nsImage = nsImage
    }
}

private struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
