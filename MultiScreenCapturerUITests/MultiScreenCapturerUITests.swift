//
//  MultiScreenCapturerUITests.swift
//  MultiScreenCapturerUITests
//
//  Created by Robert He on 2024/12/22.
//

import XCTest

final class MultiScreenCapturerUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBasicUIElements() throws {
        // Test main window elements
        XCTAssertTrue(app.buttons["Capture All Screens"].exists)
        XCTAssertTrue(app.toggles["Hide window before capture"].exists)
        XCTAssertTrue(app.toggles["Enable Screen Shadow"].exists)
        
        // Test settings elements
        XCTAssertTrue(app.textFields["Screen Spacing"].exists)
        XCTAssertTrue(app.popUpButtons["Screen Corners"].exists)
        XCTAssertTrue(app.popUpButtons["Resolution"].exists)
    }
    
    func testSaveSettings() throws {
        // Test save settings UI
        XCTAssertTrue(app.toggles["Copy to Clipboard after Capture"].exists)
        XCTAssertTrue(app.toggles["Auto Save to Path"].exists)
        
        // Enable auto save and check if browse button appears
        let autoSaveToggle = app.toggles["Auto Save to Path"]
        autoSaveToggle.click()
        
        XCTAssertTrue(app.buttons["Browse"].exists)
    }
    
    func testScreenCornerSettings() throws {
        let cornersPicker = app.popUpButtons["Screen Corners"]
        cornersPicker.click()
        
        // Verify all corner options exist
        XCTAssertTrue(app.menuItems["No Corners"].exists)
        XCTAssertTrue(app.menuItems["Main Screen Only"].exists)
        XCTAssertTrue(app.menuItems["Built-in Screen Only"].exists)
        XCTAssertTrue(app.menuItems["Built-in Screen Top Only"].exists)
        XCTAssertTrue(app.menuItems["All Screens"].exists)
        
        // Select an option that should show corner radius
        app.menuItems["All Screens"].click()
        XCTAssertTrue(app.textFields["Corner Radius"].exists)
    }
    
    @MainActor
    func testCaptureButtonState() throws {
        let captureButton = app.buttons["Capture All Screens"]
        XCTAssertTrue(captureButton.isEnabled)
        
        // Additional capture button tests can be added here
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
