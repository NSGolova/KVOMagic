//
//  ArrayKVO.swift
//  KVOMagic
//
//  Created by Viktor Radulov on 1/19/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import Foundation

class ArrayWrapper: NSObject {
    class Context: NSObject {
        weak var observer: NSObject?
        let keyPath: String
        let context: UnsafeMutableRawPointer?
        let options: NSKeyValueObservingOptions?
        
        init(_ observer: NSObject, _ keyPath: String, _ options: NSKeyValueObservingOptions?, _ context: UnsafeMutableRawPointer?) {
            self.observer = observer
            self.keyPath = keyPath
            self.context = context
            self.options = options
        }
    }
    
    var observingContexts = [Context]()
    var array: NSArray {
        didSet {
            for observingContext in (observingContexts.filter { $0.observer != nil }) {
                let observer = observingContext.observer!
                let keyPath = observingContext.keyPath
                let context = observingContext.context
                let options = observingContext.options
                
                for object in oldValue {
                    (object as? NSObject)?.removeObserver(observer, forKeyPath: keyPath, context: context)
                }
                
                for object in array {
                    (object as? NSObject)?.addObserver(observer, forKeyPath: keyPath, options: options ?? [], context: context)
                }
            }
        }
    }
    unowned(unsafe) var owner: NSObject?
    
    init?(array: Any?, owner: NSObject, keyPath: String) {
        guard let array = array as? NSArray else { return nil }
        self.array = array
        self.owner = owner
        
        super.init()
        
        owner.startObserving(keyPath) { [weak self] _, _ in
            guard let newArray = self?.owner?.value(forKeyPath: keyPath) as? NSArray else { return }
            self?.array = newArray
        }
    }
    
    override func addObserver(_ observer: NSObject, forKeyPath keyPath: String, options: NSKeyValueObservingOptions = [], context: UnsafeMutableRawPointer?) {
        observingContexts.append(Context(observer, keyPath, options, context))
        for object in (array.compactMap { $0 as? NSObject }) {
            object.addObserver(observer, forKeyPath: keyPath, options: options, context: context)
        }
    }
    
    override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        observingContexts.removeAll { $0.observer === observer && $0.keyPath == keyPath }
        for object in (array.compactMap { $0 as? NSObject }) {
            object.removeObserver(observer, forKeyPath: keyPath)
        }
    }
    
    override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String, context: UnsafeMutableRawPointer?) {
        observingContexts.removeAll { $0.observer === observer && $0.keyPath == keyPath && $0.context == context }
        for object in (array.compactMap { $0 as? NSObject }) {
            object.removeObserver(observer, forKeyPath: keyPath, context: context)
        }
    }
}

public extension String {
    static var arrayKVO: String { "$" }
}
