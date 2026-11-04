// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Grammar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Grammar",
            targets: ["Grammar"]
        ),
        .library(
            name: "GrammarTreeSitter",
            targets: ["GrammarTreeSitter"]
        ),
        .executable(
            name: "grammar_generate",
            targets: ["GrammarGenerator"]
        ),
        // testing
        .executable(
            name: "t_grammar",
            targets: ["GrammarTests"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Testing.git",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "Grammar",
            dependencies: [
                .product(name: "Primitives", package: "Primitives")
            ]
        ),
        .target(
            name: "GrammarTreeSitter",
            dependencies: [
                "Grammar",
                .product(name: "Primitives", package: "Primitives")
            ]
        ),
        .executableTarget(
            name: "GrammarGenerator",
            dependencies: ["Grammar", "GrammarTreeSitter"]
        ),
        .executableTarget(
            name: "GrammarTests",
            dependencies: [
                "Grammar",
                "GrammarTreeSitter",
                .product(name: "Testing", package: "Testing")
            ],
            path: "Testing/GrammarTests"
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
