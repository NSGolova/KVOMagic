//
//  Optionals.swift
//  KVOMagic
//
//  Created by Viktor Radulov on 1/19/21.
//  Copyright © 2021 Viktor Radulov. All rights reserved.

import Foundation

public protocol OptionalForGenerics {
    static func cast(_ value: Any) -> Any?
}

extension Optional: OptionalForGenerics {
    public static func cast(_ value: Any) -> Any? {
        value as? Wrapped
    }
}
