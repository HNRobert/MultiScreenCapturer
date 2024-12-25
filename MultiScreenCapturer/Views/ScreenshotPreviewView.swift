import SwiftUI
import Cocoa

extension NSImage: @unchecked @retroactive Sendable {}

struct ScreenshotPreviewView: View {
    let screenshot: Screenshot
    @State private var imageProvider: ImageProvider?
    @Binding var scale: CGFloat
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentMousePosition: CGPoint = .zero
    @State private var isLoading = true
    @State private var imageOpacity: Double = 0
    @State private var viewSize: CGSize = .zero
    @GestureState private var isDragging: Bool = false
    @Binding var showResetButton: Bool
    let ref: ((ScreenshotPreviewView) -> Void)?
    @State private var scrollProxy: ScrollViewProxy?
    
    init(screenshot: Screenshot, scale: Binding<CGFloat>, showResetButton: Binding<Bool>, ref: ((ScreenshotPreviewView) -> Void)? = nil) {
        self.screenshot = screenshot
        self._scale = scale
        self._showResetButton = showResetButton
        self.ref = ref
    }
    
    private var isAtDefaultState: Bool {
        let result = scale == 1.0 && offset == .zero
        showResetButton = !result
        return result
    }
    
    private func scaleAround(scale: CGFloat) {
        let previousScale = self.scale
        self.scale = max(0.5, lastScale * scale)
        
        // 计算鼠标位置相对于图片的比例位置
        let relativeX = (currentMousePosition.x - offset.width) / (viewSize.width * previousScale)
        let relativeY = (currentMousePosition.y - offset.height) / (viewSize.height * previousScale)
        
        // 计算缩放前后的尺寸差异
        let newWidth = viewSize.width * self.scale
        let newHeight = viewSize.height * self.scale
        
        // 根据鼠标位置计算新的偏移量
        offset = CGSize(
            width: currentMousePosition.x - (newWidth * relativeX),
            height: currentMousePosition.y - (newHeight * relativeY)
        )
        lastOffset = offset
        
        print("Scale: \(self.scale), Offset: \(offset), Mouse: \(currentMousePosition)")
        
        // 在更新 offset 后更新滚动位置
        updateScrollPosition()
    }
    
    private func updateScrollPosition() {
        guard let scrollProxy = scrollProxy else { return }
        
        // 计算当前视图中心点在图片上的位置
        let centerX = -offset.width + viewSize.width / 2
        let centerY = -offset.height + viewSize.height / 2
        
        // 创建一个标识此位置的 anchor
        let anchor = UnitPoint(x: centerX / (viewSize.width * scale),
                             y: centerY / (viewSize.height * scale))
        
        withAnimation(.linear(duration: 0.1)) {
            scrollProxy.scrollTo(anchor, anchor: .center)
        }
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
                updateScrollPosition()
            }
            .onEnded { value in
                lastOffset = offset
                updateScrollPosition()
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
                        ScrollViewReader { proxy in
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
                                .id(UnitPoint(x: 0.5, y: 0.5)) // 添加中心点标识
                                .overlay(
                                    GeometryReader { geo in
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let location):
                                                    if (!isDragging) {
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
                                .onAppear {
                                    scrollProxy = proxy
                                }
                        }
                    }
                    .opacity(imageOpacity)
                    .scrollDisabled(true)
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            viewSize = geo.size
                        }
                        .onChange(of: geo.size) { _, newSize in
                            if viewSize != newSize {
                                viewSize = newSize
                            }
                            scaleAround(scale: 1.0)
                        }
                }
            )
        }
        .onAppear {
            ref?(self)
            loadImageAsync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resetView()
            }
        }
        .onChange(of: scale) { _, _ in
            _ = isAtDefaultState
        }
        .onChange(of: offset) { _, _ in
            _ = isAtDefaultState
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
    
    func resetView() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            scale = 1.0
            lastScale = 1.0
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
