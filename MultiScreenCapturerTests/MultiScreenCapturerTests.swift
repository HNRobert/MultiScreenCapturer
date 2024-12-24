//
//  MultiScreenCapturerTests.swift
//  MultiScreenCapturerTests
//
//  Created by Robert He on 2024/12/22.
//

import XCTest
import SwiftData
@testable import MultiScreenCapturer

final class MultiScreenCapturerTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        modelContainer = try ModelContainer(for: Screenshot.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }
    
    func testScreenshotModelCreation() throws {
        let filepath = "/test/path/screenshot.png"
        let screenshot = Screenshot(filepath: filepath)
        
        XCTAssertNotNil(screenshot.id)
        XCTAssertEqual(screenshot.filepath, filepath)
        XCTAssertLessThanOrEqual(screenshot.timestamp.timeIntervalSinceNow, 0)
    }
    
    func testScreenshotDisplayName() throws {
        let screenshot = Screenshot(filepath: "test.png")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let expectedDate = formatter.string(from: screenshot.timestamp)
        
        XCTAssertEqual(screenshot.displayName, expectedDate)
    }
    
    func testResolutionScaleCalculation() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            XCTFail("No screens available for testing")
            return
        }
        
        // Test 1080p scale
        let scale1080p = ScreenCapturer.getResolutionScale(for: ._1080p, screens: screens)
        XCTAssertGreaterThan(scale1080p, 0)
        
        // Test 2K scale
        let scale2k = ScreenCapturer.getResolutionScale(for: ._2k, screens: screens)
        XCTAssertGreaterThan(scale2k, 0)
        
        // Test 4K scale
        let scale4k = ScreenCapturer.getResolutionScale(for: ._4k, screens: screens)
        XCTAssertGreaterThan(scale4k, 0)
        
        // Test highest DPI scale
        let scaleHighestDPI = ScreenCapturer.getResolutionScale(for: .highestDPI, screens: screens)
        XCTAssertGreaterThan(scaleHighestDPI, 0)
    }
}
