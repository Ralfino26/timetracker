// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Timetracker",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TimetrackerCore", targets: ["TimetrackerCore"])
    ],
    targets: [
        .target(
            name: "TimetrackerCore",
            path: "Sources/TimetrackerCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Timetracker",
            dependencies: ["TimetrackerCore"],
            path: "Timetracker",
            exclude: ["Info.plist"],
            resources: [.process("Assets.xcassets")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Timetracker/Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "TimetrackerCoreTests",
            dependencies: ["TimetrackerCore"],
            path: "Tests/TimetrackerCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
