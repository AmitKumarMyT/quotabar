// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PacingCore", targets: ["PacingCore"]),
        .executable(name: "QuotaBar", targets: ["QuotaBarApp"]),
        .executable(name: "QuotaBarVerification", targets: ["QuotaBarVerification"])
    ],
    targets: [
        .target(
            name: "PacingCore",
            dependencies: []
        ),
        .executableTarget(
            name: "QuotaBarApp",
            dependencies: ["PacingCore"]
        ),
        .executableTarget(
            name: "QuotaBarVerification",
            dependencies: ["PacingCore"]
        )
    ]
)
