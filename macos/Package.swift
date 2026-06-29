// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MYTGS",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "MYTGSCore", targets: ["MYTGSCore"]),
        .executable(name: "MYTGSMac", targets: ["MYTGSMac"]),
        .executable(name: "MYTGSCoreChecks", targets: ["MYTGSCoreChecks"])
    ],
    targets: [
        .target(
            name: "MYTGSCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "MYTGSMac",
            dependencies: ["MYTGSCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "MYTGSCoreChecks",
            dependencies: ["MYTGSCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
