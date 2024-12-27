//
//  MultiScreenCapturerTests.swift
//  MultiScreenCapturerTests
//
//  Created by Robert He on 2024/12/22.
//

import XCTest
@testable import MultiScreen_Capturer
import SwiftUI

final class MultiScreenCapturerTests: XCTestCase {
    func testWindowDelegateCloseBehavior() {
        let delegate = WindowDelegate()
        delegate.shouldTerminateOnClose = false  // Disable termination in tests
        let window = NSWindow()
        
        XCTAssertTrue(delegate.windowShouldClose(window))
    }
    
    func testWindowAccessor() {
        let expectation = XCTestExpectation(description: "Window callback called")
        
        let testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        let testView = NSView()
        testWindow.contentView = testView
        
        let accessor = WindowAccessor { window in
            XCTAssertEqual(window, testWindow)
            expectation.fulfill()
        }
        
        let hostingView = NSHostingView(rootView: accessor)
        testWindow.contentView?.addSubview(hostingView)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

