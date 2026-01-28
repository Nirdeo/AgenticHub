// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AgenticHub",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgenticHub", targets: ["AgenticHub"])
    ],
    targets: [
        .executableTarget(
            name: "AgenticHub",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
