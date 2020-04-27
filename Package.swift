// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCrash",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftType",
            dependencies: []),
        .target(
            name: "SwiftCrash",
            dependencies: ["SwiftType"]),
        .testTarget(
            name: "SwiftCrashTests",
            dependencies: ["SwiftCrash"]),
    ]
)
