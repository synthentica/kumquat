// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Converter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Converter", targets: ["Converter"]),
        .library(name: "ConverterCore", targets: ["ConverterCore"]),
    ],
    targets: [
        .target(
            name: "ConverterCore",
            path: "Sources/ConverterCore"
        ),
        .executableTarget(
            name: "Converter",
            dependencies: ["ConverterCore"],
            path: "Sources/Converter"
        ),
        .testTarget(
            name: "ConverterCoreTests",
            dependencies: ["ConverterCore"],
            path: "Tests/ConverterCoreTests"
        ),
    ]
)
