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

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the main window exists
        XCTAssertTrue(app.windows.element.exists)
        XCTAssertTrue(app.buttons["Capture All Screens"].exists)
        
        // Verify the window title
        XCTAssertEqual(app.windows.firstMatch.title, "MultiScreen Capturer")

        // Record a screenshot of the launch screen.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
