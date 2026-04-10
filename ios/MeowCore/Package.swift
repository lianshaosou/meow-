// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MeowCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MeowDomain", targets: ["MeowDomain"]),
        .library(name: "MeowSimulation", targets: ["MeowSimulation"]),
        .library(name: "MeowLocation", targets: ["MeowLocation"]),
        .library(name: "MeowData", targets: ["MeowData"]),
        .library(name: "MeowFeatures", targets: ["MeowFeatures"])
    ],
    targets: [
        .target(name: "MeowDomain"),
        .target(name: "MeowSimulation", dependencies: ["MeowDomain"]),
        .target(name: "MeowLocation", dependencies: ["MeowDomain"]),
        .target(name: "MeowData", dependencies: ["MeowDomain"]),
        .target(
            name: "MeowFeatures",
            dependencies: ["MeowDomain", "MeowLocation", "MeowSimulation", "MeowData"]
        ),
        .testTarget(name: "MeowSimulationTests", dependencies: ["MeowSimulation"]),
        .testTarget(name: "MeowLocationTests", dependencies: ["MeowLocation"]),
        .testTarget(name: "MeowFeaturesTests", dependencies: ["MeowFeatures"]),
        .testTarget(name: "MeowDataTests", dependencies: ["MeowData"])
    ]
)
