// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GrammarTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // testing
        .executable(
            name: "t_grammar",
            targets: ["GrammarTests"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-tooling/Testing.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Errors.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "GrammarTests",
            dependencies: [
                .product(name: "Errors", package: "Errors"),
                .product(name: "Grammar", package: "Grammar"),
                .product(name: "GrammarTreeSitter", package: "Grammar"),
                .product(name: "Testing", package: "Testing")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
