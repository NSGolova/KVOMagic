//
//  PropertyWrappers.swift
//  KVOMagic
//
//  Created by Viktor Radulov on 1/19/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import Foundation

protocol OwnedWrapper {
    var anyOwner: Any? { get set }
    var ownerKeypath: String? { get set }
}

protocol ObjectOwnedWrapper {
    var owner: NSObject? { get set }
    var ownerKeypath: String? { get set }
}

extension NSObject {
    func initWrappers() {
        let mirror = Mirror(reflecting: self)
        for (key, value) in mirror.children {
            guard let keyPath = key?.replacingOccurrences(of: "_", with: "") else { continue }
            if var wrapper = value as? OwnedWrapper {
                wrapper.ownerKeypath = keyPath
                wrapper.anyOwner = self
            }
            if var wrapper = value as? ObjectOwnedWrapper {
                wrapper.ownerKeypath = keyPath
                wrapper.owner = self
            }
        }
    }
}

class WrapperOwner: NSObject {
    override init() {
        super.init()
        
        initWrappers()
    }
}

@propertyWrapper
class UIProperty<PropertyType>: ObjectOwnedWrapper {
    var ownerKeypath: String?
    var owner: NSObject?
    
    init(wrappedValue: PropertyType) {
        storredValue = wrappedValue
    }
    
    var storredValue: PropertyType
    var wrappedValue: PropertyType {
        get {
            storredValue
        }
        set {
            assert(owner != nil, "Use me only in WrapperOwner subclasses!")
            guard let owner = owner, let ownerKeypath = ownerKeypath else { return }
            let block = {
                owner.willChangeValue(forKey: ownerKeypath)
                self.storredValue = newValue
                owner.didChangeValue(forKey: ownerKeypath)
            }
            
            if Thread.current == Thread.main {
                block()
            } else {
                DispatchQueue.main.sync(execute: block)
            }
        }
    }
}

extension NSObject {
    
    static var arrayKVOContext: NSObject?
    var wrappers: [String: ArrayWrapper] {
        get {
            (objc_getAssociatedObject(self, &NSObject.arrayKVOContext) as? [String: ArrayWrapper]) ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &NSObject.arrayKVOContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func arrayCompatibleValue(forKey key: String, defaultValue: (String) -> Any?) -> Any? {
        let prefix = String.arrayKVO
        if key.hasPrefix(prefix) {
            let keyPath = String(key.dropFirst(prefix.count))
            if let wrapper = wrappers[keyPath] {
                return wrapper
            }
            let result = ArrayWrapper(array: defaultValue(keyPath), owner: self, keyPath: keyPath)
            wrappers[keyPath] = result
            
            return result
        } else {
            return defaultValue(key)
        }
    }
}

@propertyWrapper
class Computed<PropertyType, Owner>: OwnedWrapper where Owner: NSObject {
    let affectings: [String]
    let block: (Owner) -> PropertyType
    
    private var owner: Owner! {
        didSet {
            updateStoredValue()
        }
    }
    var ownerKeypath: String?
    var anyOwner: Any? {
        get {
            return owner
        }
        set {
            guard let owner = newValue as? Owner else { return }
            
            self.owner = owner
            for affecting in affectings {
                owner.startObserving(affecting, self, options: [.initial]) { [weak self] _, _ in
                    guard let self = self,
                          self.updateTimer == nil else { return }
                    
                    let timeFromUpdate = Date().timeIntervalSince(self.lastUpdate)
                    if timeFromUpdate < self.changeRate {
                        self.updateTimer = Timer.scheduledTimer(withTimeInterval: self.changeRate - timeFromUpdate, repeats: false, block: { [weak self] _ in
                            self?.updateTimer = nil
                            self?.sendNotifications()
                        })
                    } else {
                        self.sendNotifications()
                    }
                }
            }
        }
    }
    
    private func sendNotifications() {
        guard let ownerKeypath = ownerKeypath else { return }
        
        owner.willChangeValue(forKey: ownerKeypath)
        updateStoredValue()
        owner.didChangeValue(forKey: ownerKeypath)
        
        lastUpdate = Date()
    }
    
    // typeProvider is used only for generics.
    // Should be `self` in majority of cases.
    init(_ block: @escaping (Owner) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, changeRate: TimeInterval = 0.1, _ affectings: String...) {
        self.affectings = affectings
        self.block = block
        self.changeRate = changeRate
    }
    
    private lazy var lastUpdate = Date(timeIntervalSinceNow: -(changeRate * 2))
    private var updateTimer: Timer?
    private let changeRate: TimeInterval
    
    var storedValue: PropertyType?
    var wrappedValue: PropertyType {
        storedValue ?? block(owner)
    }
    
    func updateStoredValue() {
        storedValue = block(owner)
    }
}

// Revisit me after Swift has templates implemented
@propertyWrapper
class Computed1<PropertyType, Owner, Affected>: OwnedWrapper where Owner: NSObject {
    let affecting: KeyPath<Owner, Affected>
    let block: (Affected) -> PropertyType
    
    private var owner: Owner! {
        didSet {
            updateStoredValue()
        }
    }
    var ownerKeypath: String?
    var anyOwner: Any? {
        get {
            return owner
        }
        set {
            guard let owner = newValue as? Owner else { return }
            self.owner = owner
            owner.startObserving(affecting, self, options: [.initial]) { [weak self] owner, _ in
                guard let self = self, let ownerKeypath = self.ownerKeypath else { return }
                
                owner.willChangeValue(forKey: ownerKeypath)
                self.updateStoredValue()
                owner.didChangeValue(forKey: ownerKeypath)
            }
        }
    }

    var storedValue: PropertyType?
    var wrappedValue: PropertyType {
        storedValue ?? block(owner[keyPath: affecting])
    }
    
    init(_ block: @escaping (Affected) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, _ affecting: KeyPath<Owner, Affected>) {
        self.affecting = affecting
        self.block = block
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affecting])
    }
}

@propertyWrapper
class Computed2<PropertyType, Owner, Affected1, Affected2>: OwnedWrapper where Owner: NSObject {
    let affectings: (KeyPath<Owner, Affected1>, KeyPath<Owner, Affected2>)
    let block: (Affected1, Affected2) -> PropertyType
    
    private var owner: Owner! {
        didSet {
            updateStoredValue()
        }
    }
    var ownerKeypath: String?
    var anyOwner: Any? {
        get {
            return owner
        }
        set {
            guard let owner = newValue as? Owner else { return }
            self.owner = owner
            let observing: (Owner) -> Void = { [weak self] owner in
                guard let self = self, let ownerKeypath = self.ownerKeypath else { return }
                
                owner.willChangeValue(forKey: ownerKeypath)
                self.updateStoredValue()
                owner.didChangeValue(forKey: ownerKeypath)
            }
            
            owner.startObserving(affectings.0, self, options: [.initial]) { owner, _ in observing(owner) }
            owner.startObserving(affectings.1, self, options: [.initial]) { owner, _ in observing(owner) }
        }
    }
    var storedValue: PropertyType?
    var wrappedValue: PropertyType {
        storedValue ?? block(owner[keyPath: affectings.0], owner[keyPath: affectings.1])
    }
    
    init(_ block: @escaping (Affected1, Affected2) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, _ affecting1: KeyPath<Owner, Affected1>, _ affecting2: KeyPath<Owner, Affected2>) {
        self.affectings = (affecting1, affecting2)
        self.block = block
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affectings.0], owner[keyPath: affectings.1])
    }
}

@propertyWrapper
class Computed3<T, M, U1, U2, U3>: OwnedWrapper where M: NSObject {
    let affectings: (KeyPath<M, U1>, KeyPath<M, U2>, KeyPath<M, U3>)
    let block: (U1, U2, U3) -> T
    
    private var owner: M! {
        didSet {
            updateStoredValue()
        }
    }
    var ownerKeypath: String?
    var anyOwner: Any? {
        get {
            return owner
        }
        set {
            guard let owner = newValue as? M else { return }
            self.owner = owner
            
            let observing: (M) -> Void = { [weak self] owner in
                guard let self = self, let ownerKeypath = self.ownerKeypath else { return }
                
                owner.willChangeValue(forKey: ownerKeypath)
                self.updateStoredValue()
                owner.didChangeValue(forKey: ownerKeypath)
            }
            
            owner.startObserving(affectings.0, self, options: [.initial]) { owner, _ in observing(owner) }
            owner.startObserving(affectings.1, self, options: [.initial]) { owner, _ in observing(owner) }
            owner.startObserving(affectings.2, self, options: [.initial]) { owner, _ in observing(owner) }
        }
    }

    init(_ block: @escaping (U1, U2, U3) -> T, _ typeProvider: (M) -> () -> M, _ affecting1: KeyPath<M, U1>, _ affecting2: KeyPath<M, U2>, _ affecting3: KeyPath<M, U3>) {
        
        self.affectings = (affecting1, affecting2, affecting3)
        self.block = block
    }
    
    var storedValue: T?
    var wrappedValue: T {
        storedValue ?? block(owner[keyPath: affectings.0], owner[keyPath: affectings.1], owner[keyPath: affectings.2])
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affectings.0], owner[keyPath: affectings.1], owner[keyPath: affectings.2])
    }
}

class ArrayOwner: WrapperOwner {
    override func value(forKey key: String) -> Any? {
        arrayCompatibleValue(forKey: key, defaultValue: { super.value(forKey: $0) })
    }
    
    // Don't reorder this calls!
    // ...except you know what you're doing
    override func willChangeValue(forKey key: String) {
        if wrappers[key] != nil {
            super.willChangeValue(forKey: .arrayKVO + key)
        }
        
        super.willChangeValue(forKey: key)
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        
        if wrappers[key] != nil {
            super.didChangeValue(forKey: .arrayKVO + key)
        }
    }
}
