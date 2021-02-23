//
//  ArrayKVOTests.swift
//  KVOMagicTests
//
//  Created by Viktor Radulov on 2/22/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import XCTest
@testable import KVOMagic

class ArrayKVOTests: XCTestCase {

    func testObservingStatic() {
        let object1 = TestObservable()
        let object2 = TestObservable()
        let object3 = TestObservable()
        let arrayOwner = TestArrayOwner(list: [object1, object2, object3])
        
        let expectation = XCTestExpectation(description: "KVO block should be called")
        expectation.expectedFulfillmentCount = 3
        
        arrayOwner.startObserving(.arrayKVO + #keyPath(TestArrayOwner.list.testIntProperty)) { _, _ in
            expectation.fulfill()
        }
        object1.testIntProperty = 1
        object2.testIntProperty = 2
        object3.testIntProperty = 3
        wait(for: [expectation], timeout: 1)
    }

    func testObservingDynamic() {
        let object1 = TestObservable()
        let object2 = TestObservable()
        let object3 = TestObservable()
        let arrayOwner = TestArrayOwner()
        
        let expectation = XCTestExpectation(description: "KVO block should be called")
        expectation.expectedFulfillmentCount = 3
        
        arrayOwner.startObserving(.arrayKVO + #keyPath(TestArrayOwner.list.testIntProperty)) { _, _ in
            expectation.fulfill()
        }
        object1.testIntProperty = 1
        object2.testIntProperty = 2
        object3.testIntProperty = 3
        
        arrayOwner.add(observable: object1)
        arrayOwner.add(observable: object2)
        arrayOwner.add(observable: object3)
        
        object1.testIntProperty = 2
        object2.testIntProperty = 3
        object3.testIntProperty = 4
        
        wait(for: [expectation], timeout: 1)
    }
}
