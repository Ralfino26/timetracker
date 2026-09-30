// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Timetracker",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Timetracker",
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
        )
    ]
)
