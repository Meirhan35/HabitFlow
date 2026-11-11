// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HabitFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HabitFlow", targets: ["HabitFlow"])
    ],
    targets: [
        .executableTarget(
            name: "HabitFlow",
            path: "Sources/HabitFlow",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HabitFlowTests",
            dependencies: ["HabitFlow"],
            path: "Tests/HabitFlowTests"
        )
    ]
)
