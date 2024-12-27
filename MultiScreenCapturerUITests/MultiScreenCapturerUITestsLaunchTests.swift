//
//  MultiScreenCapturerUITestsLaunchTests.swift
//  MultiScreenCapturerUITests
//
//  Created by Robert He on 2024/12/22.
//

import XCTest

final class MultiScreenCapturerUITestsLaunchTests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched successfully and wait for window
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        
        // Add small delay to ensure all animations complete
        Thread.sleep(forTimeInterval: 1.0)
        
        // Don't terminate here - let tearDown handle it
    }
    
    override func tearDownWithError() throws {
        // Add delay to ensure all tests are complete
        Thread.sleep(forTimeInterval: 2.0)
        
        let app = XCUIApplication()
        if app.state == .runningForeground {
            app.terminate()
        }
        
        try super.tearDownWithError()
    }
}
