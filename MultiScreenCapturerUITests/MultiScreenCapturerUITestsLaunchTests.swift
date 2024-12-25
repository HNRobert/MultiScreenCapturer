//
//  MultiScreenCapturerUITestsLaunchTests.swift
//  MultiScreenCapturerUITests
//
//  Created by Robert He on 2024/12/22.
//

import XCTest

final class MultiScreenCapturerUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched successfully
        XCTAssertTrue(app.windows.firstMatch.exists)
        
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

