import AppKit
import Foundation
import SwiftData

struct CaptureSettings {
    let cornerStyle: ScreenCornerStyle
    let cornerRadius: Double
    let screenSpacing: Int
    let enableShadow: Bool
    let resolutionStyle: ResolutionStyle
    let copyToClipboard: Bool
    let autoSaveToPath: String?
}

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

    static func getResolutionScale(for style: ResolutionStyle, screens: [NSScreen]) -> CGFloat {
        switch style {
        case ._1080p:
            return 1080.0 / screens[0].frame.height
        case ._2k:
            return 1440.0 / screens[0].frame.height
        case ._4k:
            return 2160.0 / screens[0].frame.height
        case .highestDPI:
            return screens.map { $0.backingScaleFactor }.max() ?? 1.0
        }
    }
    
    static func shouldApplyCornersRadius(for screen: NSScreen, style: ScreenCornerStyle) -> (apply: Bool, topOnly: Bool) {
        switch style {
        case .none:
            return (false, false)
        case .mainOnly:
            return (screen == NSScreen.main, false)
        case .builtInOnly:
            return (screen.localizedName.contains("Built-in"), false)
        case .builtInTopOnly:
            return (screen.localizedName.contains("Built-in"), true)
        case .all:
            return (true, false)
        }
    }

    private static let macOSWindowShadow: NSShadow = {
        let shadow = NSShadow()
        // Simulate macOS window shadow
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.shadowBlurRadius = 12
        return shadow
    }()
    
    static func captureAllScreens(with settings: CaptureSettings = .init(
        cornerStyle: .none,
        cornerRadius: 35,
        screenSpacing: 10,
        enableShadow: true,
        resolutionStyle: .highestDPI,
        copyToClipboard: false,
        autoSaveToPath: nil
    )) -> NSImage? {
        if !CGPreflightScreenCaptureAccess() {
            checkScreenCapturePermission()
            return nil
        }

        let screens = NSScreen.screens
        let scale = getResolutionScale(for: settings.resolutionStyle, screens: screens)

        // Calculate total frame with spacing
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

        let spacing = CGFloat(settings.screenSpacing)
        let totalFrame = NSRect(
            x: 0, y: 0,
            width: (maxX - minX + spacing) * scale,
            height: (maxY - minY + spacing) * scale
        )

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
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
        context?.imageInterpolation = .high
        NSGraphicsContext.current = context

        for screen in screens {
            if let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               let screenShot = CGDisplayCreateImage(displayId) {
                let frame = screen.frame
                var relativeFrame = CGRect(
                    x: (frame.origin.x - minX + spacing) * scale,
                    y: (frame.origin.y - minY + spacing) * scale,
                    width: frame.width * scale,
                    height: frame.height * scale
                )

                let nsImage = NSImage(cgImage: screenShot, size: frame.size)

                if settings.enableShadow {
                    NSGraphicsContext.current?.saveGraphicsState()
                    macOSWindowShadow.set()
                }

                let cornerSettings = shouldApplyCornersRadius(for: screen, style: settings.cornerStyle)
                if cornerSettings.apply {
                    if cornerSettings.topOnly {
                        // Top corners only
                        let path = NSBezierPath()
                        let radius = CGFloat(settings.cornerRadius)
                        path.move(to: NSPoint(x: relativeFrame.minX, y: relativeFrame.minY))
                        path.line(to: NSPoint(x: relativeFrame.minX, y: relativeFrame.maxY - radius))
                        path.appendArc(withCenter: NSPoint(x: relativeFrame.minX + radius, y: relativeFrame.maxY - radius),
                                     radius: radius,
                                     startAngle: 180,
                                     endAngle: 90,
                                     clockwise: true)
                        path.line(to: NSPoint(x: relativeFrame.maxX - radius, y: relativeFrame.maxY))
                        path.appendArc(withCenter: NSPoint(x: relativeFrame.maxX - radius, y: relativeFrame.maxY - radius),
                                     radius: radius,
                                     startAngle: 90,
                                     endAngle: 0,
                                     clockwise: true)
                        path.line(to: NSPoint(x: relativeFrame.maxX, y: relativeFrame.minY))
                        path.close()
                        NSGraphicsContext.current?.saveGraphicsState()
                        path.addClip()
                    } else {
                        // All corners
                        let path = NSBezierPath(roundedRect: relativeFrame,
                                              xRadius: CGFloat(settings.cornerRadius),
                                              yRadius: CGFloat(settings.cornerRadius))
                        NSGraphicsContext.current?.saveGraphicsState()
                        path.addClip()
                    }
                }

                nsImage.draw(in: relativeFrame)

                if settings.enableShadow {
                    NSGraphicsContext.current?.restoreGraphicsState()
                } else if cornerSettings.apply {
                    NSGraphicsContext.current?.restoreGraphicsState()
                }
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        let finalImage = NSImage(size: totalFrame.size)
        finalImage.addRepresentation(bitmapRep)

        if settings.copyToClipboard {
            copyToClipboard(finalImage)
        }

        if let path = settings.autoSaveToPath {
            saveToPath(finalImage, path: path)
        }

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

    static func loadThumbnail(from filepath: String) -> NSImage? {
        guard let originalImage = NSImage(contentsOfFile: filepath) else { return nil }
        
        let thumbnailSize = NSSize(width: 100, height: 100)
        let thumbnail = NSImage(size: thumbnailSize)
        
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let aspectRatio = originalImage.size.width / originalImage.size.height
        let targetRect: NSRect
        if aspectRatio > 1 {
            let newHeight = thumbnailSize.width / aspectRatio
            targetRect = NSRect(x: 0, y: (thumbnailSize.height - newHeight) / 2, width: thumbnailSize.width, height: newHeight)
        } else {
            let newWidth = thumbnailSize.height * aspectRatio
            targetRect = NSRect(x: (thumbnailSize.width - newWidth) / 2, y: 0, width: newWidth, height: thumbnailSize.height)
        }
        originalImage.draw(in: targetRect,
                 from: NSRect(origin: .zero, size: originalImage.size),
                 operation: .copy,
                 fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }

    static func copyToClipboard(_ image: NSImage) {
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData) {
            NSPasteboard.general.clearContents()
            
            if let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                NSPasteboard.general.setData(pngData, forType: .png)
            }
            
            NSPasteboard.general.setData(tiffData, forType: .tiff)
        }
    }
    
    static func saveToPath(_ image: NSImage, path: String) {
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            let url = URL(fileURLWithPath: path)
                .appendingPathComponent("screenshot-\(Date().timeIntervalSince1970).png")
            try? pngData.write(to: url)
        }
    }
}
