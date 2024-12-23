import AppKit
import Foundation
import SwiftData

class ScreenCapturer {
    static func checkScreenCapturePermission() {
        let checkOptionPrompt = true
        let hasPermission = CGPreflightScreenCaptureAccess()

        if !hasPermission {
            let wasGranted = CGRequestScreenCaptureAccess()
            if !wasGranted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Need Screen Recording Permission"
                    alert.informativeText = "Please grant the app permission to record the screen."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Open System Settings")
                    alert.addButton(withTitle: "Cancel")

                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(
                            URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                            )!)
                    }
                }
            }
        }
    }

    static func captureAllScreens() -> NSImage? {
        if !CGPreflightScreenCaptureAccess() {
            checkScreenCapturePermission()
            return nil
        }

        let screens = NSScreen.screens

        // 找出最高的缩放因子（DPI）
        let maxScale = screens.map { $0.backingScaleFactor }.max() ?? 1.0

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

        let totalFrame = CGRect(
            x: 0, y: 0,
            width: maxX - minX,
            height: maxY - minY)

        // 使用最高DPI计算实际像素尺寸
        let pixelWidth = Int(totalFrame.width * maxScale)
        let pixelHeight = Int(totalFrame.height * maxScale)

        guard
            let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0)
        else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        context?.imageInterpolation = .high
        NSGraphicsContext.current = context

        for screen in screens {
            if let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
            {
                let frame = screen.frame
                let relativeFrame = CGRect(
                    x: (frame.origin.x - minX) * maxScale,
                    y: (frame.origin.y - minY) * maxScale,
                    width: frame.width * maxScale,
                    height: frame.height * maxScale
                )

                if let screenShot = CGDisplayCreateImage(displayId) {
                    let nsImage = NSImage(cgImage: screenShot, size: frame.size)
                    nsImage.draw(in: relativeFrame)
                }
            }
        }

        NSGraphicsContext.restoreGraphicsState()

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
                    let pngData = bitmapImage.representation(using: .png, properties: [:])
                {
                    try? pngData.write(to: url)
                }
            }
        }
    }

    static func saveToSandbox(_ image: NSImage, context: ModelContext) -> Screenshot? {
        guard
            let documentDirectory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else {
            return nil
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "screenshot-\(formatter.string(from: now)).png"
        let fileURL = documentDirectory.appendingPathComponent(filename)

        if let tiffData = image.tiffRepresentation,
            let bitmapImage = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapImage.representation(using: .png, properties: [:])
        {
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
