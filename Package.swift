// swift-tools-version:5.9
// Gói SwiftPM chỉ để TEST phần logic thuần của shell (PhimVietKit) bằng swift-testing.
// App input method thật được build bằng scripts/build_bundle.sh (không cần Xcode).
// Cần build lõi Rust trước: scripts/build_rust_universal.sh (make test làm sẵn).
import Foundation
import PackageDescription

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"

let package = Package(
    name: "PhimViet",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PhimVietKit", targets: ["PhimVietKit"])],
    targets: [
        .systemLibrary(name: "PhimVietFFI", path: "ffi/include"),
        .target(
            name: "PhimVietKit",
            dependencies: ["PhimVietFFI"],
            path: "macos/PhimViet",
            sources: ["Composition", "Shared", "EngineBridge.swift"],
            linkerSettings: [.unsafeFlags(["-L\(root)/build/rust"])]
        ),
        .testTarget(
            name: "PhimVietKitTests",
            dependencies: ["PhimVietKit"],
            path: "macos/PhimVietTests",
            // Chỉ có Command Line Tools: swift-testing nằm ở đây (Xcode tự tìm được, flag thừa vô hại).
            swiftSettings: [.unsafeFlags(["-F", cltFrameworks])],
            linkerSettings: [.unsafeFlags(["-F", cltFrameworks, "-Xlinker", "-rpath", "-Xlinker", cltFrameworks])]
        ),
    ]
)
