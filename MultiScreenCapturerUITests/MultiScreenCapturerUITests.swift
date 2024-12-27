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
        
        // Add cleanup as the last operation
        addTeardownBlock {
            Thread.sleep(forTimeInterval: 2.0)
            if self.app.state == .runningForeground {
                self.app.terminate()
            }
            return
        }
    }
    
    func testWindowTitle() throws {
        // Wait for window with title and verify
        let window = app.windows["MultiScreen Capturer"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        
        // Add small delay to ensure UI is stable
        Thread.sleep(forTimeInterval: 1.0)
        
        // Don't terminate here
    }
    
    override func tearDownWithError() throws {
        // Let the teardown block handle termination
        try super.tearDownWithError()
    }
}

