// swift-tools-version: 5.9
import PackageDescription

// Pure Foundation logic with no UIKit or AVFoundation, so `swift test`
// can run it on a Mac without an iPhone or simulator.
let package = Package(
    name: "SonicSwipeCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SonicSwipeCore", targets: ["SonicSwipeCore"])
    ],
    targets: [
        .target(name: "SonicSwipeCore"),
        .testTarget(name: "SonicSwipeCoreTests", dependencies: ["SonicSwipeCore"])
    ]
)
