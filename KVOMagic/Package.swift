// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "KVOMagic",
    platforms: [.macOS("10.12"), .iOS(.v10), .tvOS(.v10)],
    products: [
        .library(name: "KVOMagic", targets: ["KVOMagic"])
    ],
    targets: [
        .target(
            name: "KVOMagic",
            path: "KVOMagic"
        )
    ]
)
