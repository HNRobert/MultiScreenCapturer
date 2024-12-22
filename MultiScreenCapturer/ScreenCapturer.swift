import Foundation
import AppKit
import SwiftData

class ScreenCapturer {
    static func checkScreenCapturePermission() {
        // 检查是否已经有屏幕录制权限
        let checkOptionPrompt = true
        let hasPermission = CGPreflightScreenCaptureAccess()
        
        if !hasPermission {
            // 请求权限
            let wasGranted = CGRequestScreenCaptureAccess()
            if !wasGranted {
                DispatchQueue.main.async {
                    // 显示提示，引导用户去系统偏好设置中授权
                    let alert = NSAlert()
                    alert.messageText = "需要屏幕录制权限"
                    alert.informativeText = "请在系统设置中允许屏幕录制权限"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "打开系统设置")
                    alert.addButton(withTitle: "取消")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    }
                }
            }
        }
    }

    static func captureAllScreens() -> NSImage? {
        // 确保有权限
        if !CGPreflightScreenCaptureAccess() {
            checkScreenCapturePermission()
            return nil
        }
        
        let screens = NSScreen.screens
        
        // 计算所有屏幕组成的总区域
        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var maxY: CGFloat = -.infinity
        
        for screen in screens {
            let frame = screen.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }
        
        let totalFrame = CGRect(x: 0, y: 0, 
                              width: maxX - minX, 
                              height: maxY - minY)
        
        // 创建位图上下文
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(totalFrame.width),
            pixelsHigh: Int(totalFrame.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0) else {
            return nil
        }
        
        // 创建图形上下文
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        
        // 使用 CGDisplayCreateImage 来截取每个屏幕
        for screen in screens {
            if let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                let frame = screen.frame
                let relativeFrame = CGRect(
                    x: frame.origin.x - minX,
                    y: frame.origin.y - minY,
                    width: frame.width,
                    height: frame.height
                )
                
                if let screenShot = CGDisplayCreateImage(displayId) {
                    let nsImage = NSImage(cgImage: screenShot, size: frame.size)
                    nsImage.draw(in: relativeFrame)
                }
            }
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        // 创建最终图像
        let finalImage = NSImage(size: totalFrame.size)
        finalImage.addRepresentation(bitmapRep)
        
        return finalImage
    }
    
    static func saveScreenshot(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "screenshot.png"
        
        guard let mainWindow = NSApp.mainWindow else { return }
        savePanel.beginSheetModal(for: mainWindow) { response in
            if response == .OK {
                guard let url = savePanel.url else { return }
                
                if let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
    
    static func saveToSandbox(_ image: NSImage, context: ModelContext) -> Screenshot? {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "screenshot-\(Date().timeIntervalSince1970).png"
        let fileURL = documentDirectory.appendingPathComponent(filename)
        
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
            
            let screenshot = Screenshot(filepath: fileURL.path)
            context.insert(screenshot)
            return screenshot
        }
        
        return nil
    }
    
    static func loadImage(from filepath: String) -> NSImage? {
        return NSImage(contentsOfFile: filepath)
    }
}
