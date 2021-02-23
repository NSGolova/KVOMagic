//
//  TestObjects.swift
//  KVOMagicTests
//
//  Created by Viktor Radulov on 2/22/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import Foundation
import KVOMagic
import SwiftUI

class TestObservable: NSObject {
    @objc dynamic var testIntProperty = 0
    @objc dynamic var testObjectProperty: NSObject?
    @objc dynamic var testStringProperty = ""
}

class TestObserver: NSObject {
    @objc dynamic var testProperty: TestObservable?
    
    func observeSelf(handler: @escaping (TestObserver) -> Void) {
        startObserving(\.testProperty?.testIntProperty) { observer, _ in
            handler(observer)
        }
    }
    
    func ownedObserveSelf(handler: @escaping (TestObserver) -> Void) {
        startObserving(\.testProperty?.testIntProperty, self) { observer, _ in
            handler(observer)
        }
    }
}

class TestArrayOwner: ArrayOwner {
    @objc dynamic var list = [TestObservable]()
    
    init(list: [TestObservable] = []) {
        self.list = list
    }
    
    func add(observable: TestObservable) {
        list.append(observable)
    }
    
    func remove(observable: TestObservable) {
        list.removeAll { $0 == observable }
    }
}

class TestNestedArrayOwner: ArrayOwner {
    @objc dynamic var list = [TestArrayOwner]()
    
    func add(observable: TestArrayOwner) {
        list.append(observable)
    }
    
    func remove(observable: TestArrayOwner) {
        list.removeAll { $0 == observable }
        
        
    }
}

class TestWrapperOwner: WrapperOwner {
    @objc dynamic var name = "test"
    @objc dynamic var surname = "test1"
    @objc dynamic var nickname = "tes"
    
    @Computed1({ $0.uppercased() }, self, \.name) @objc dynamic var uppercasedName
    @Computed2({ $0 + " " + $1 }, self, \.name, \.surname) @objc dynamic var fullname
    @Computed3({ $0 + "(\($1))" + $2 }, self, \.name, \.nickname, \.surname) @objc dynamic var title
    
    @Computed({ $0.name + " " + $0.surname }, self, #keyPath(name), #keyPath(surname)) @objc dynamic var fullname1
}
