import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CaptureSettings {
    let cornerStyle: ScreenCornerStyle
    let cornerRadius: Double
    let screenSpacing: Int
    let enableShadow: Bool
    let resolutionStyle: ResolutionStyle
    let copyToClipboard: Bool
    let hideWindowBeforeCapture: Bool
    let mainWindow: NSWindow?
    let autoSaveEnabled: Bool
    let autoSavePath: String
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
    
    private static func areScreensAdjacent(_ screen1: NSScreen, _ screen2: NSScreen, spacing: CGFloat) -> (horizontal: Bool, vertical: Bool, ascendH: Bool, ascendV: Bool) {
        let frame1 = screen1.frame
        let frame2 = screen2.frame
        
        // Check if screens overlap in vertical direction
        let verticalOverlap = frame1.minY < frame2.maxY && frame2.minY < frame1.maxY
        // Check if screens overlap in horizontal direction
        let horizontalOverlap = frame1.minX < frame2.maxX && frame2.minX < frame1.maxX
        
        // Check if screens are adjacent horizontally
        let horizontalAdjacent = verticalOverlap && (
            abs(frame1.maxX - frame2.minX) < spacing || abs(frame2.maxX - frame1.minX) < spacing
        )
        
        // Check if screens are adjacent vertically
        let verticalAdjacent = horizontalOverlap && (
            abs(frame1.maxY - frame2.minY) < spacing || abs(frame2.maxY - frame1.minY) < spacing
        )
        
        // Determine if screen2 is to the right of screen1
        let ascendH = frame2.midX > frame1.midX
        
        // Determine if screen2 is above screen1
        let ascendV = frame2.midY > frame1.midY
        
        return (horizontalAdjacent, verticalAdjacent, ascendH, ascendV)
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
                let adjacent = areScreensAdjacent(screen1, screen2, spacing: spacing)
                
                if adjacent.horizontal {
                    adjustedPositions[adjacent.ascendH ? screen2 : screen1]?.x += spacing
                }
                if adjacent.vertical {
                    adjustedPositions[adjacent.ascendV ? screen2 : screen1]?.y += spacing
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
        hideWindowBeforeCapture: false,
        mainWindow: nil,
        autoSaveEnabled: false,
        autoSavePath: ""
    )) -> Screenshot? {
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
        let margin = settings.enableShadow ? max(shadowMargin, spacing) : spacing
        
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
                
                // 保存当前图形状态
                NSGraphicsContext.current?.saveGraphicsState()
                
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
                        path.addClip()
                    } else {
                        // All corners
                        let path = NSBezierPath(roundedRect: relativeFrame,
                                              xRadius: CGFloat(settings.cornerRadius),
                                              yRadius: CGFloat(settings.cornerRadius))
                        path.addClip()
                    }
                }

                // 先绘制阴影
                if settings.enableShadow {
                    // 创建阴影路径
                    let shadowPath = cornerSettings.apply ? 
                        (cornerSettings.topOnly ? 
                            NSBezierPath(rect: NSRect(x: relativeFrame.minX, y: relativeFrame.minY,
                                                    width: relativeFrame.width, height: relativeFrame.height - CGFloat(settings.cornerRadius))) :
                            NSBezierPath(roundedRect: relativeFrame,
                                       xRadius: CGFloat(settings.cornerRadius),
                                       yRadius: CGFloat(settings.cornerRadius))) :
                        NSBezierPath(rect: relativeFrame)
                    
                    macOSWindowShadow.set()
                    shadowPath.fill()
                }

                // 绘制图像
                nsImage.draw(in: relativeFrame)
                
                // 恢复图形状态
                NSGraphicsContext.current?.restoreGraphicsState()
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        let outPutImage = NSImage(size: totalFrame.size)
        outPutImage.addRepresentation(bitmapRep)

        // Restore window visibility
        if settings.hideWindowBeforeCapture && isWindowHidden {
            DispatchQueue.main.async {
                settings.mainWindow?.orderFront(nil)
            }
        }

        if settings.copyToClipboard {
            copyToClipboard(outPutImage)
        }
        
        let screenPositions = screens.map { screen in
            let frame = screen.frame
            let adjustedPosition = adjustedPositions[screen] ?? frame.origin
            return ScreenPosition(
                id: Int32(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0),
                frame: CGRect(
                    x: (adjustedPosition.x - minX) * scale + margin,
                    y: (adjustedPosition.y - minY) * scale + margin,
                    width: frame.width * scale,
                    height: frame.height * scale
                )
            )
        }
        
        let finalImage = saveToSandbox(outPutImage, screenPositions: screenPositions)

        if settings.autoSaveEnabled && !settings.autoSavePath.isEmpty {
            if let finalImage = finalImage {
                let autoSavePath = settings.autoSavePath
                let sourceFilename = (finalImage.filepath as NSString).lastPathComponent
                let autoSaveURL = URL(fileURLWithPath: autoSavePath).appendingPathComponent(sourceFilename)
                do {
                    try FileManager.default.copyItem(atPath: finalImage.filepath, toPath: autoSaveURL.path)
                } catch let error {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Failed to save screenshot at \(autoSavePath)"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }

        return finalImage
    }

    static func saveScreenshot(_ screenshot: Screenshot) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png"]
        panel.nameFieldStringValue = (screenshot.filepath as NSString).lastPathComponent + ".png"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try FileManager.default.copyItem(atPath: screenshot.filepath, toPath: url.path)
                } catch {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Failed to save screenshot at \(url.path)"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }

    static func convertToPNGData(_ image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData
    }

    private static func saveImageWithMetadata(_ image: NSImage, metadata: ScreenMetadata, to url: URL) -> Bool {
        guard let imageData = convertToPNGData(image) else { return false }
        guard let metadataJson = try? JSONEncoder().encode(metadata) else { return false }
        guard let metadataString = String(data: metadataJson, encoding: .utf8) else { return false }
        
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil as CFDictionary?)
        guard let destination = dest else { return false }
        
        let properties = [
            kCGImagePropertyPNGDictionary: [
                "Metadata": metadataString
            ]
        ] as CFDictionary
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        CGImageDestinationAddImage(destination, cgImage, properties)
        return CGImageDestinationFinalize(destination)
    }
    
    static func extractScreenImage(_ screenshot: Screenshot, screenPosition: ScreenPosition) -> NSImage? {
        guard let originalImage = NSImage(contentsOfFile: screenshot.filepath) else { return nil }
        let cropRect = screenPosition.frame
        
        let croppedImage = NSImage(size: cropRect.size)
        croppedImage.lockFocus()
        originalImage.draw(in: NSRect(origin: .zero, size: cropRect.size),
                         from: cropRect,
                         operation: .copy,
                         fraction: 1.0)
        croppedImage.unlockFocus()
        
        return croppedImage
    }
    
    static func saveToSandbox(_ image: NSImage, screenPositions: [ScreenPosition]) -> Screenshot? {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        try? FileManager.default.createDirectory(at: documentDirectory, withIntermediateDirectories: true)
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "screenshot-\(formatter.string(from: now)).png"
        let fileURL = documentDirectory.appendingPathComponent(filename)
        
        let metadata = ScreenMetadata(screenCount: screenPositions.count, screenPositions: screenPositions)
        if saveImageWithMetadata(image, metadata: metadata, to: fileURL) {
            return Screenshot(
                id: UUID(),
                timestamp: now,
                filepath: fileURL.path,
                metadata: metadata
            )
        }
        
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
        if let tiffData = image.tiffRepresentation {
            NSPasteboard.general.clearContents()
            
            if let pngData = convertToPNGData(image) {
                NSPasteboard.general.setData(pngData, forType: .png)
            }
            NSPasteboard.general.setData(tiffData, forType: .tiff)
        }
    }
}
