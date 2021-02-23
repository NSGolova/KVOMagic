# KVOMagic

The framework to enhance KVO usage in Swift. 

## Features

- Array KVO
- Affecting property wrapper 
- AddObserver with auto removing

## Installing

### Submodule

You can add this project as a submodule and incorporate KVOMagic.xcodeproj.

### Cocoapods 

// TODO

### Swift Package Manager

1. Using Xcode go to File > Swift Packages > Add Package Dependency
2. Paste the project URL: https://github.com/radulov/KVOMagic.git
3. Click on next and select the project target:
    - KVOMagic

If you have doubts, please, check the following links:

[How to use](https://developer.apple.com/videos/play/wwdc2019/408/)

[Creating Swift Packages](https://developer.apple.com/videos/play/wwdc2019/410/)

After successfully retrieved the package and added it to your project, just import `KVOMagic` and you can get the full benefits of it.

### Binary

Grab last artifacts from [GithubActions](https://github.com/radulov/KVOMagic/actions) or from [Release](https://github.com/radulov/KVOMagic/releases) page

## Usage

### Array KVO

You can add an observer for every object in an array by using a special keyPath prefix - "$".
Typical usage: `.arrayKVO + #keyPath(arrayOwner.arrayProperty.propertyOfObjectInArray)`

For example you have such structure:
```swift
class MyObject: NSObject {
    @objc dynamic var intProperty: Int
}
class MyObjectsCollection: ArrayOwner {
    @objc dynamic var array: [MyObject]
}
```
You can add an observer for every object in array by one line:
```swift
let collection = MyObjectsCollection()
collection.startObserving(.arrayKVO + #keyPath(MyObjectsCollection.array.intProperty)) { _, _ in
    \\ Do some stuff here
}
```
So whenever `intProperty` will be changed, you will receive a callback.
For everything to work, you need to subclass `ArrayOwner` and make sure all your properties support objc runtime.

Array KVO supports all kinds of usage, such as:
- KeyPathForValuesAffecting
- Mutable array
- Affecting property wrapper
- Nested observing

### Affecting property wrapper

Property wrapper for encapsulating `KeyPathForValuesAffecting()` and support for swift KeyPath.
It will also cache computed value and change it only on new KVO notifications.

Classical example:
```swift
class Contact: WrapperOwner {
    @objc dynamic var name: String?
    @objc dynamic var surname: String?
    
    @Computed2({ $0 + " " + $1 }, self, \.name, \.surname) @objc dynamic var fullname
}
```
There are four flavours:
```swift
@Computed1({ $0 }, self, \.keyPath) @objc dynamic var name
@Computed2({ $0, $1 }, self, \.keyPath1, \.keyPath2) @objc dynamic var name
@Computed3({ $0, $1, $2 }, self, \.keyPath1, \.keyPath2, \.keyPath3) @objc dynamic var name
```
These three are type-safe and use Swift KeyPath. Every time value for any of provided properties will change, the computing block will be called with an appropriate count of arguments.

```swift
@Computed({ `self` in }, self, #keyPath("stringKeypath")) @objc dynamic var name
```
This one is using String keyPath and will pass `self` as an argument to "computing block". This property wrapper can accept various count of affecting keyPaths.

### AddObserver with auto removing

New `observe()` function analogue called `startObserving()`.
The key differences are:
- No need for storing an observer object. An observer will remove automatically in `deinit()`.
- Fixed self-observing crash. You can safely observe properties from the `self` object.
- Fixed removing observer in `.initial` callback. You can safely call `stopObserving()` even in the first callback called immediately after `startObserving()`

There are two flavours:
```swift
func startObserving<Value>(_ keyPath: KeyPath<Self, Value>, _ owner: Any? = nil, options: NSKeyValueObservingOptions = [], changeHandler: @escaping (Self, KeyValueObservedChange<Value>) -> Void) {}
```
Typesafe variant with swift KeyPath.

```swift
func startObserving(_ keyPath: String, _ owner: Any? = nil, options: NSKeyValueObservingOptions = [], changeHandler: @escaping (Self, KeyValueObservedChange<Any>) -> Void)
```
Obj-c equivalent with string keyPath.

### Code snippets

Copy content of the [Code snippets](/KVOMagic/CodeSnippets) folder to ‘~/Library/Developer/Xcode/UserData/CodeSnippets’.

## Samples

Check unit tests for the samples.
 
## Requirements to Build the Project

1. Pull this repository.
2. Change Apple ID account in Signing&Capabilities;
3. Specific macOS and Xcode versions (see KVOMagic.xcodeproj, Xcode 12.4, and MacOS 10.15.7 for now).

# Development Process

## Git Branching Model

[Git-flow](http://nvie.com/posts/a-successful-git-branching-model/)


## Coding Style

* [Google Coding Standard](https://google.github.io/swift)
* [Swift Lint](https://github.com/realm/SwiftLint/blob/master/Rules.md)


## Versioning

Every version number is described as:
```
x.y.z
```
Where:
* x – major version;
* y – minor version;
* z – bugfix version.
