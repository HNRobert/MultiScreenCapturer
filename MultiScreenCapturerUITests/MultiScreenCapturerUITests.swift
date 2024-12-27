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
        
        addTeardownBlock {
            Thread.sleep(forTimeInterval: 2.0)
            if self.app.state == .runningForeground {
                self.app.terminate()
            }
            return
        }
    }
    
    func testWindowTitle() throws {
        let window = app.windows["MultiScreen Capturer"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
}

