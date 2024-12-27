import AppKit
import Foundation

struct CaptureSettings {
    let cornerStyle: ScreenCornerStyle
    let cornerRadius: Double
    let screenSpacing: Int
    let enableShadow: Bool
    let resolutionStyle: ResolutionStyle
    let copyToClipboard: Bool
    let autoSaveToPath: String?
    let hideWindowBeforeCapture: Bool
    let mainWindow: NSWindow?
}

class ScreenCapturer {
    private static var thumbnailCache = NSCache<NSString, NSImage>()
    private static let shadowMargin: CGFloat = 50
    
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
    
    private static func areScreensAdjacent(_ screen1: NSScreen, _ screen2: NSScreen) -> (horizontal: Bool, vertical: Bool) {
        let frame1 = screen1.frame
        let frame2 = screen2.frame
        
        // Check if screens overlap in vertical direction
        let verticalOverlap = frame1.minY < frame2.maxY && frame2.minY < frame1.maxY
        // Check if screens overlap in horizontal direction
        let horizontalOverlap = frame1.minX < frame2.maxX && frame2.minX < frame1.maxX
        
        // Check if screens are adjacent horizontally
        let horizontalAdjacent = verticalOverlap && (
            abs(frame1.maxX - frame2.minX) < 1 || abs(frame2.maxX - frame1.minX) < 1
        )
        
        // Check if screens are adjacent vertically
        let verticalAdjacent = horizontalOverlap && (
            abs(frame1.maxY - frame2.minY) < 1 || abs(frame2.maxY - frame1.minY) < 1
        )
        
        return (horizontalAdjacent, verticalAdjacent)
    }
    
    private static func calculateAdjustedScreenPositions(screens: [NSScreen], spacing: CGFloat) -> [NSScreen: NSPoint] {
        var adjustedPositions: [NSScreen: NSPoint] = [:]
        
        // Initialize with original positions
        for screen in screens {
            adjustedPositions[screen] = NSPoint(x: screen.frame.minX, y: screen.frame.minY)
        }
        
        // Calculate adjustments
        for i in 0..<screens.count-1 {
            for j in (i+1)..<screens.count {
                let screen1 = screens[i]
                let screen2 = screens[j]
                let adjacent = areScreensAdjacent(screen1, screen2)
                
                if adjacent.horizontal || adjacent.vertical {
                    let frame1 = screen1.frame
                    let frame2 = screen2.frame
                    
                    // If screen2 is to the right of screen1
                    if frame2.minX > frame1.minX && adjacent.horizontal {
                        adjustedPositions[screen2]?.x += spacing
                    }
                    // If screen2 is below screen1
                    if frame2.minY > frame1.minY && adjacent.vertical {
                        adjustedPositions[screen2]?.y += spacing
                    }
                }
            }
        }
        
        return adjustedPositions
    }

    static func captureAllScreens(with settings: CaptureSettings = .init(
        cornerStyle: .none,
        cornerRadius: 35,
        screenSpacing: 10,
        enableShadow: true,
        resolutionStyle: .highestDPI,
        copyToClipboard: false,
        autoSaveToPath: nil,
        hideWindowBeforeCapture: false,
        mainWindow: nil
    )) -> NSImage? {
        // Temporarily hide window if needed
        var isWindowHidden = false
        if settings.hideWindowBeforeCapture {
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.main.async {
                isWindowHidden = settings.mainWindow?.isVisible ?? false
                settings.mainWindow?.orderOut(nil)
                group.leave()
            }
            group.wait()
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Capture screens
        let screens = NSScreen.screens
        let scale = getResolutionScale(for: settings.resolutionStyle, screens: screens)
        let spacing = CGFloat(settings.screenSpacing)
        let margin = settings.enableShadow ? shadowMargin : 0
        
        // Calculate adjusted positions
        let adjustedPositions = calculateAdjustedScreenPositions(screens: screens, spacing: spacing)
        
        // Calculate total frame with adjusted positions
        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var maxY: CGFloat = -.infinity
        
        for screen in screens {
            let frame = screen.frame
            let adjustedPosition = adjustedPositions[screen] ?? frame.origin
            minX = min(minX, adjustedPosition.x)
            minY = min(minY, adjustedPosition.y)
            maxX = max(maxX, adjustedPosition.x + frame.width)
            maxY = max(maxY, adjustedPosition.y + frame.height)
        }

        let totalFrame = NSRect(
            x: 0, y: 0,
            width: (maxX - minX) * scale + (margin * 2),
            height: (maxY - minY) * scale + (margin * 2)
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
                let adjustedPosition = adjustedPositions[screen] ?? frame.origin
                let relativeFrame = CGRect(
                    x: (adjustedPosition.x - minX) * scale + margin,
                    y: (adjustedPosition.y - minY) * scale + margin,
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

        // Restore window visibility
        if settings.hideWindowBeforeCapture && isWindowHidden {
            DispatchQueue.main.async {
                settings.mainWindow?.orderFront(nil)
            }
        }

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

    static func saveToSandbox(_ image: NSImage) -> Screenshot? {
        guard
            let documentDirectory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else {
            print("Failed to get document directory")
            return nil
        }

        try? FileManager.default.createDirectory(at: documentDirectory, withIntermediateDirectories: true)

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "screenshot-\(formatter.string(from: now)).png"
        let fileURL = documentDirectory.appendingPathComponent(filename)

        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:])
        {
            do {
                try pngData.write(to: fileURL)
                return Screenshot(
                    id: UUID(),
                    timestamp: now,
                    filepath: fileURL.path
                )
            } catch {
                print("Failed to save image: \(error.localizedDescription)")
                return nil
            }
        }

        print("Failed to convert image to PNG")
        return nil
    }

    static func loadImage(from filepath: String) async -> NSImage? {
        guard FileManager.default.fileExists(atPath: filepath) else {
            print("Image file not found at path: \(filepath)")
            return nil
        }
        
        return NSImage(contentsOfFile: filepath)
    }

    static func loadThumbnail(from filepath: String) -> NSImage? {
        let key = filepath as NSString
        
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        
        guard FileManager.default.fileExists(atPath: filepath) else {
            print("Thumbnail file not found at path: \(filepath)")
            return nil
        }
        
        guard let originalImage = NSImage(contentsOfFile: filepath) else { 
            print("Failed to load image for thumbnail: \(filepath)")
            return nil 
        }
        
        let thumbnailSize = NSSize(width: 100, height: 100)
        let thumbnail = NSImage(size: thumbnailSize)
        
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let aspectRatio = originalImage.size.width / originalImage.size.height
        let targetRect: NSRect
        if (aspectRatio > 1) {
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
        
        thumbnailCache.setObject(thumbnail, forKey: key)
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
