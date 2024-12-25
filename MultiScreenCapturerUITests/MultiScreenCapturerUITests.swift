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
    
    func testWindowTitle() throws {
        XCTAssertTrue(app.windows["MultiScreen Capturer"].exists)
    }
}

