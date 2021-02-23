//
//  PropertyWrappersTests.swift
//  KVOMagicTests
//
//  Created by Viktor Radulov on 2/23/21.
//

import XCTest
@testable import KVOMagic

class PropertyWrappersTests: XCTestCase {

    func testFullname() {
        let wrapperOwner = TestWrapperOwner()
        var expectedFullname = ""
        
        let expectation = XCTestExpectation(description: "KVO block should be called")
        expectation.expectedFulfillmentCount = 2
        wrapperOwner.startObserving(\.fullname) { wrapperOwner, _ in
            XCTAssertEqual(expectedFullname, wrapperOwner.fullname)
            expectation.fulfill()
        }
        expectedFullname = "Testy test1"
        wrapperOwner.name = "Testy"
        expectedFullname = "Testy Testor"
        wrapperOwner.surname = "Testor"
        
        wait(for: [expectation], timeout: 1)
    }

}
