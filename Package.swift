// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BioChemPet",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BioChemCore", targets: ["BioChemCore"]),
        .library(name: "BioChemUI", targets: ["BioChemUI"]),
        .executable(name: "BioChemPet", targets: ["BioChemPet"])
    ],
    targets: [
        .target(name: "BioChemCore", resources: [.copy("Resources")]),
        .target(name: "BioChemUI", dependencies: ["BioChemCore"]),
        .executableTarget(name: "BioChemPet", dependencies: ["BioChemUI", "BioChemCore"]),
        .target(name: "BioChemTestSupport", dependencies: ["BioChemCore"], path: "Tests/Support"),
        .executableTarget(name: "BioChemCheck", dependencies: ["BioChemCore", "BioChemTestSupport"], path: "Checks"),
        .testTarget(name: "BioChemCoreTests", dependencies: ["BioChemCore", "BioChemTestSupport"])
    ]
)
