//
//  PropertyWrappers.swift
//  KVOMagic
//
//  Created by Viktor Radulov on 1/19/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import Foundation
import Combine
import SwiftUI

protocol OwnedWrapper {
    var anyOwner: Any? { get set }
    var ownerKeypath: String? { get set }
}

protocol ObjectOwnedWrapper {
    var owner: NSObject? { get set }
    var ownerKeypath: String? { get set }
}

public protocol WrapperOwnerProtocol: class {
    func initWrappers()
}

extension WrapperOwnerProtocol where Self: NSObject {
    public func initWrappers() {
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

extension WrapperOwnerProtocol {
    
    @available(OSXApplicationExtension 10.15, *)
    public func initWrappers() {
        let mirror = Mirror(reflecting: self)
        for (key, value) in mirror.children {
            guard let keyPath = key?.replacingOccurrences(of: "_", with: "") else { continue }
            if var wrapper = value as? OwnedWrapper {
                wrapper.ownerKeypath = keyPath
                wrapper.anyOwner = self
            }
        }
    }
}

open class WrapperOwner: NSObject, WrapperOwnerProtocol {
    public override init() {
        super.init()
        
        initWrappers()
    }
}

@available(OSXApplicationExtension 10.15, *)
open class PureWrapperOwner: WrapperOwnerProtocol {
    
    public init() {
        initWrappers()
    }
}

@propertyWrapper
public class UIProperty<PropertyType>: ObjectOwnedWrapper {
    var ownerKeypath: String?
    var owner: NSObject?
    
    public init(wrappedValue: PropertyType) {
        storredValue = wrappedValue
    }
    
    var storredValue: PropertyType
    public var wrappedValue: PropertyType {
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
public class Computed<PropertyType, Owner>: OwnedWrapper where Owner: NSObject {
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
    public init(_ block: @escaping (Owner) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, changeRate: TimeInterval = 0.1, _ affectings: String...) {
        self.affectings = affectings
        self.block = block
        self.changeRate = changeRate
    }
    
    private lazy var lastUpdate = Date(timeIntervalSinceNow: -(changeRate * 2))
    private var updateTimer: Timer?
    private let changeRate: TimeInterval
    
    var storedValue: PropertyType?
    public var wrappedValue: PropertyType {
        storedValue ?? block(owner)
    }
    
    func updateStoredValue() {
        storedValue = block(owner)
    }
}

// Revisit me after Swift has templates implemented
@propertyWrapper
public class Computed1<PropertyType, Owner, A>: OwnedWrapper where Owner: NSObject {
    let affecting: KeyPath<Owner, A>
    let block: (A) -> PropertyType
    
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
    public var wrappedValue: PropertyType {
        storedValue ?? block(owner[keyPath: affecting])
    }
    
    public init(_ block: @escaping (A) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, _ affecting: KeyPath<Owner, A>) {
        self.affecting = affecting
        self.block = block
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affecting])
    }
}

@propertyWrapper
public class Computed2<PropertyType, Owner, A, B>: OwnedWrapper where Owner: NSObject {
    let affectings: (KeyPath<Owner, A>, KeyPath<Owner, B>)
    let block: (A, B) -> PropertyType
    
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
    public var wrappedValue: PropertyType {
        storedValue ?? block(owner[keyPath: affectings.0], owner[keyPath: affectings.1])
    }
    
    public init(_ block: @escaping (A, B) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, _ affecting1: KeyPath<Owner, A>, _ affecting2: KeyPath<Owner, B>) {
        self.affectings = (affecting1, affecting2)
        self.block = block
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affectings.0], owner[keyPath: affectings.1])
    }
}

@propertyWrapper
public class Computed3<PropertyType, Owner, A, B, C>: OwnedWrapper where Owner: NSObject {
    let affectings: (KeyPath<Owner, A>, KeyPath<Owner, B>, KeyPath<Owner, C>)
    let block: (A, B, C) -> PropertyType
    
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
            owner.startObserving(affectings.2, self, options: [.initial]) { owner, _ in observing(owner) }
        }
    }

    public init(_ block: @escaping (A, B, C) -> PropertyType, _ typeProvider: (Owner) -> () -> Owner, _ affecting1: KeyPath<Owner, A>, _ affecting2: KeyPath<Owner, B>, _ affecting3: KeyPath<Owner, C>) {
        
        self.affectings = (affecting1, affecting2, affecting3)
        self.block = block
    }
    
    var storedValue: PropertyType?
    public var wrappedValue: PropertyType {
        storedValue ?? block(owner[keyPath: affectings.0], owner[keyPath: affectings.1], owner[keyPath: affectings.2])
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affectings.0], owner[keyPath: affectings.1], owner[keyPath: affectings.2])
    }
}

@available(OSXApplicationExtension 10.15, *)
@propertyWrapper
public class ObservableArray<T>: ObservableObject where T: ObservableObject  {

    @Published public var wrappedValue = [T]() {
        didSet {
            observeChildrenChanges()
        }
    }
    var cancellables = [AnyCancellable]()

    public init(wrappedValue: [T]) {
        self.wrappedValue = wrappedValue
        
        observeChildrenChanges()
    }

    func observeChildrenChanges() {
        wrappedValue.forEach({
            let cancellable = $0.objectWillChange.sink { _ in
                self.objectWillChange.send()
            }

            self.cancellables.append(cancellable)
        })
    }
    
    public var projectedValue: ObservableArray<T> {
        self
    }
}

@available(OSXApplicationExtension 10.15, *)
@propertyWrapper
public class FromArray<PropertyType, Owner, Value>: OwnedWrapper
where Owner: ObservableObject,
      Owner.ObjectWillChangePublisher == ObservableObjectPublisher,
      Value: ObservableObject {
    
    var ownerKeypath: String?
    let affectings: KeyPath<Owner, ObservableArray<Value>>
    let block: ([Value]) -> PropertyType
    
    private var owner: Owner! {
        didSet {
            updateStoredValue()
            
            observer = owner[keyPath: affectings].objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.owner.objectWillChange.send()
                self?.updateStoredValue()
            }
        }
    }
    var observer: AnyCancellable?
    var anyOwner: Any? {
        get {
            return owner
        }
        set {
            guard let owner = newValue as? Owner else { return }
            self.owner = owner
            
            updateStoredValue()
        }
    }
    
    public static subscript(
          instanceSelf observed: Owner,
          wrapped wrappedKeyPath: ReferenceWritableKeyPath<Owner, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<Owner, FromArray>
        ) -> PropertyType {
        get {
          observed[keyPath: storageKeyPath].wrappedValue
        }
      }

    public init(_ block: @escaping ([Value]) -> PropertyType, _ affecting: KeyPath<Owner, ObservableArray<Value>>) {
        
        self.affectings = affecting
        self.block = block
    }
    
    var storedValue: PropertyType?
    public var wrappedValue: PropertyType {
        storedValue ?? block(owner[keyPath: affectings].wrappedValue)
    }
    
    func updateStoredValue() {
        storedValue = block(owner[keyPath: affectings].wrappedValue)
    }
}

open class ArrayOwner: WrapperOwner {
    public override func value(forKey key: String) -> Any? {
        arrayCompatibleValue(forKey: key, defaultValue: { super.value(forKey: $0) })
    }
    
    // Don't reorder this calls!
    // ...except you know what you're doing
    public override func willChangeValue(forKey key: String) {
        if wrappers[key] != nil {
            super.willChangeValue(forKey: .arrayKVO + key)
        }
        
        super.willChangeValue(forKey: key)
    }
    
    public override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        
        if wrappers[key] != nil {
            super.didChangeValue(forKey: .arrayKVO + key)
        }
    }
}
