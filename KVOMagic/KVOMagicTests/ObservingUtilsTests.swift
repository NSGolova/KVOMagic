//
//  ObservingUtilsTests.swift
//  KVOMagicTests
//
//  Created by Viktor Radulov on 2/22/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import XCTest
@testable import KVOMagic

class ObservingUtilsTests: XCTestCase {
    func testObservingWithOwner() {
        let observable = TestObservable()
        var observer: TestObserver? = TestObserver()
        var shouldBeCalled = true
        let expectation = XCTestExpectation(description: "KVO block should be called")
        observable.startObserving(\.testIntProperty, observer) { _, _ in
            expectation.fulfill()
            XCTAssert(shouldBeCalled, "Observing block should not be called after owner death")
        }
        observable.testIntProperty = 1
        wait(for: [expectation], timeout: 1)
        observer = nil
        shouldBeCalled = false
        observable.testIntProperty = 2
    }
    
    func testObservingWithoutOwner() {
        var observable: TestObservable? = TestObservable()
        let expectation = XCTestExpectation(description: "KVO block should be called")
        observable?.startObserving(\.testIntProperty) { _, _ in
            expectation.fulfill()
        }
        observable?.testIntProperty = 1
        wait(for: [expectation], timeout: 1)
        weak var weakObservable = observable
        XCTAssert(weakObservable != nil)
        observable = nil
        XCTAssert(weakObservable == nil, "KVO without owner should not retain observable")
    }
    
    func testObservingWithMultipleOwners() {
        let observable = TestObservable()
        let observer1 = TestObserver()
        let observer2 = TestObserver()
        
        let expectation1 = XCTestExpectation(description: "KVO block should be called for all observers")
        observable.startObserving(\.testIntProperty, observer1) { _, _ in
            expectation1.fulfill()
        }
        let expectation2 = XCTestExpectation(description: "KVO block should be called for all observers")
        observable.startObserving(\.testIntProperty, observer2) { _, _ in
            expectation2.fulfill()
        }
        observable.testIntProperty = 1
        wait(for: [expectation1, expectation2], timeout: 1)
    }
    
    func testMultipleObservingWithoutOwner() {
        let observable = TestObservable()
        
        let expectation1 = XCTestExpectation(description: "KVO block should be called for all observers")
        observable.startObserving(\.testIntProperty) { _, _ in
            expectation1.fulfill()
        }
        let expectation2 = XCTestExpectation(description: "KVO block should be called for all observers")
        observable.startObserving(\.testIntProperty) { _, _ in
            expectation2.fulfill()
        }
        observable.testIntProperty = 1
        wait(for: [expectation1, expectation2], timeout: 1)
    }
    
    func testStopObservingWithOwner() {
        let observable = TestObservable()
        let observer = TestObserver()
        
        var shouldBeCalled = true
        let expectation = XCTestExpectation(description: "KVO block should be called")
        observable.startObserving(\.testIntProperty, observer) { _, _ in
            expectation.fulfill()
            XCTAssert(shouldBeCalled, "Observing block should not be called after stop observing call")
        }
        observable.testIntProperty = 1
        wait(for: [expectation], timeout: 1)
        observable.stopObserving(\.testIntProperty, observer)
        shouldBeCalled = false
        observable.testIntProperty = 2
    }
    
    func testSelfObserving() {
        let observable = TestObservable()
        var observer: TestObserver? = TestObserver()
        var shouldBeCalled = true
        
        observer?.testProperty = observable
        let expectation = XCTestExpectation(description: "KVO block should be called")
        observer?.observeSelf { [weak observer] innerObserver in
            XCTAssert(observer === innerObserver, "Self should be sent to KVO handler")
            expectation.fulfill()
            XCTAssert(shouldBeCalled, "Observing block should not be called after observable death")
        }
        observable.testIntProperty = 1
        wait(for: [expectation], timeout: 1)
        weak var weakObserver = observer
        XCTAssert(weakObserver != nil)
        observer = nil
        XCTAssert(weakObserver == nil, "KVO without owner should not retain observer")
        shouldBeCalled = false
        observable.testIntProperty = 2
    }
    
    func testOwnedSelfObserving() {
        let observable = TestObservable()
        var observer: TestObserver? = TestObserver()
        var shouldBeCalled = true
        
        observer?.testProperty = observable
        let expectation = XCTestExpectation(description: "KVO block should be called")
        observer?.ownedObserveSelf { [weak observer] innerObserver in
            XCTAssert(observer === innerObserver, "Self should be sent to KVO handler")
            expectation.fulfill()
            XCTAssert(shouldBeCalled, "Observing block should not be called after owner death")
        }
        observable.testIntProperty = 1
        wait(for: [expectation], timeout: 1)
        weak var weakObserver = observer
        XCTAssert(weakObserver != nil)
        observer = nil
        XCTAssert(weakObserver == nil, "KVO with owner should not retain observer")
        shouldBeCalled = false
        observable.testIntProperty = 2
    }
}
