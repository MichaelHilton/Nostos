// swift-tools-version: 5.7.1
import PackageDescription

let package = Package(
    name: "Nostos",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Nostos",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Nostos",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NostosTests",
            dependencies: [
                "Nostos",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            path: "Tests/NostosTests"
        ),
        .testTarget(
            name: "NostosUITests",
            dependencies: [
                "Nostos",
            ],
            path: "Tests/NostosUITests"
        )
    ]
)
