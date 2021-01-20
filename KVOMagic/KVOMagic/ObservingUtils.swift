//
//  ObservingUtils.swift
//  KVOMagic
//
//  Created by Viktor Radulov on 1/19/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import Foundation
import ObjectiveC

public extension NSObjectProtocol where Self: NSObject {
    func startObserving<Value>(_ keyPath: KeyPath<Self, Value>, _ owner: Any? = nil, options: NSKeyValueObservingOptions = [], changeHandler: @escaping (Self, KeyValueObservedChange<Value>) -> Void) {
        let uuid: NSObject = UUID() as NSObject

        let contextPtr = owner != nil ? &|self : &|uuid
        let observer = KeyValueObserver<Value, Self>(object: self, keyPath, options: options) { object, change in
            let converter = { (changeValue: Any?) -> Value? in
                guard let optionalType = Value.self as? OptionalForGenerics.Type,
                      let unwrapped = changeValue else { return changeValue as? Value }
                
                let nullEliminatedValue = optionalType.cast(unwrapped) as Any
                let transformedOptional = nullEliminatedValue
                return transformedOptional as? Value
            }
            
            let notification = KeyValueObservedChange(kind: change.kind,
                                                      newValue: converter(change.newValue),
                                                      oldValue: converter(change.oldValue),
                                                      indexes: change.indexes,
                                                      isPrior: change.isPrior)
            changeHandler(object, notification)
        }
        
        var observers = objc_getAssociatedObject(owner ?? self, contextPtr) as? [String: KeyValueObserverProtocol]
        if observers == nil {
            observers = [:]
        }
        
        guard let keyPath = observer.path else { return }
        
        assert(owner == nil || observers?[keyPath] == nil)
        observers?[keyPath] = observer
        objc_setAssociatedObject(owner ?? self, contextPtr, observers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        observer.start()
    }
    
    func startObserving(_ keyPath: String, _ owner: Any? = nil, options: NSKeyValueObservingOptions = [], changeHandler: @escaping (Self, KeyValueObservedChange<Any>) -> Void) {
        let uuid: NSObject = UUID() as NSObject

        let contextPtr = owner != nil ? &|self : &|uuid
        let observer = KeyValueObserver<Any, Self>(object: self, keyPath, options: options, changeHandler: changeHandler)
        
        var observers = objc_getAssociatedObject(owner ?? self, contextPtr) as? [String: KeyValueObserverProtocol]
        if observers == nil {
            observers = [:]
        }
        
        guard let keyPath = observer.path else { return }
        
        assert(owner == nil || observers?[keyPath] == nil)
        observers?[keyPath] = observer
        objc_setAssociatedObject(owner ?? self, contextPtr, observers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        observer.start()
    }
    
    func startObserving<Object: NSObject, Value>(_ object: Object,
                                                 _ keyPath: KeyPath<Object, Value>,
                                                 _ owner: Any? = nil,
                                                 options: NSKeyValueObservingOptions = [],
                                                 changeHandler: @escaping (Object, KeyValueObservedChange<Value>) -> Void) {
        let nsObject: NSObject = object
        nsObject.startObserving(keyPath._kvcKeyPathString!, owner, options: options) { object, change in
            guard let object = object as? Object else { return }
            
            changeHandler(object, KeyValueObservedChange(kind: change.kind,
                                                         newValue: change.newValue as? Value,
                                                         oldValue: change.oldValue as? Value,
                                                         indexes: change.indexes,
                                                         isPrior: change.isPrior))
        }
    }
    
    func stopObserving<Object: NSObject, Value>(_ object: Object,
                                                _ keyPath: KeyPath<Object, Value>,
                                                _ owner: Any? = nil) {
        object.stopObserving(keyPath, owner)
    }
    
    func stopObserving<Value>(_ keyPath: KeyPath<Self, Value>, _ owner: Any?) {
        guard let keyPath = keyPath._kvcKeyPathString else { return }
        stopObserving(keyPath, owner)
    }
    
    func stopObserving(_ keyPath: String, _ owner: Any?) {
        guard let owner = owner else { return }
        var observers = objc_getAssociatedObject(owner, &|self) as? [String: KeyValueObserverProtocol]
        
        observers?[keyPath]?.invalidate()
        observers?[keyPath] = nil
        
        objc_setAssociatedObject(owner, &|self, observers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

public struct KeyValueObservedChange<Value> {
    public typealias Kind = NSKeyValueChange
    public let kind: KeyValueObservedChange<Value>.Kind
    public let newValue: Value?
    public let oldValue: Value?
    public let indexes: IndexSet?
    public let isPrior: Bool
}

protocol KeyValueObserverProtocol {
    func invalidate()
}

public class KeyValueObserver<Value, Object: NSObject>: NSObject, KeyValueObserverProtocol {
    var changeHandler: ((Object, KeyValueObservedChange<Any>) -> Void)?
    let path: String?
    let options: NSKeyValueObservingOptions
    unowned(unsafe) var object: Object?
    
    init(object: Object, _ keyPath: KeyPath<Object, Value>, options: NSKeyValueObservingOptions = [], changeHandler: @escaping (Object, KeyValueObservedChange<Any>) -> Void) {
        self.changeHandler = changeHandler
        self.object = object
        self.path = keyPath._kvcKeyPathString
        self.options = options
        
        super.init()
    }
    
    init(object: Object, _ stringKeyPath: String, options: NSKeyValueObservingOptions = [], changeHandler: @escaping (Object, KeyValueObservedChange<Any>) -> Void) {
        self.changeHandler = changeHandler
        self.object = object
        self.path = stringKeyPath
        self.options = options
        
        super.init()
    }
    
    // swiftlint:disable block_based_kvo
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let object = object as? Object,
              let change = change,
              let rawKind = change[NSKeyValueChangeKey.kindKey] as? UInt,
              let kind = NSKeyValueChange(rawValue: rawKind) else { return }
        
        let notification = KeyValueObservedChange(kind: kind,
                                                  newValue: change[NSKeyValueChangeKey.newKey],
                                                  oldValue: change[NSKeyValueChangeKey.oldKey],
                                                  indexes: change[NSKeyValueChangeKey.indexesKey] as? IndexSet,
                                                  isPrior: change[NSKeyValueChangeKey.notificationIsPriorKey] as? Bool ?? false)
        changeHandler?(object, notification)
    }
    
    func start() {
        guard let stringPath = path else { return }
        
        object?.addObserver(self, forKeyPath: stringPath, options: options, context: nil)
    }
    
    func invalidate() {
        invalidate(async: true)
    }
    
    private func invalidate(async: Bool) {
        guard let stringPath = path else { return }
        changeHandler = nil

        // Async here for weird edge case:
        // `Stop observing called in .initial KVO-message callback`.
        // It should be async because this callback performed in addObserver() call.
        // Before observer is added
        if async && options.contains(.initial) {
            DispatchQueue.main.async {
                self.object?.removeObserver(self, forKeyPath: stringPath)
                self.object = nil
            }
        } else {
            object?.removeObserver(self, forKeyPath: stringPath)
            object = nil
        }
    }
    
    deinit {
        invalidate(async: false)
    }
}
