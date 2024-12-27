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

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    override func tearDownWithError() throws {
        Thread.sleep(forTimeInterval: 2.0)
        
        let app = XCUIApplication()
        if app.state == .runningForeground {
            app.terminate()
        }
        
        try super.tearDownWithError()
    }
}
