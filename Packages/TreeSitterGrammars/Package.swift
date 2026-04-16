// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TreeSitterGrammars",
    products: [
        .library(name: "TreeSitterBash", targets: ["TreeSitterBash"]),
        .library(name: "TreeSitterC", targets: ["TreeSitterC"]),
        .library(name: "TreeSitterCPP", targets: ["TreeSitterCPP"]),
        .library(name: "TreeSitterCSharp", targets: ["TreeSitterCSharp"]),
        .library(name: "TreeSitterCSS", targets: ["TreeSitterCSS"]),
        .library(name: "TreeSitterGo", targets: ["TreeSitterGo"]),
        .library(name: "TreeSitterHTML", targets: ["TreeSitterHTML"]),
        .library(name: "TreeSitterJavaScript", targets: ["TreeSitterJavaScript"]),
        .library(name: "TreeSitterJSON", targets: ["TreeSitterJSON"]),
        .library(name: "TreeSitterPython", targets: ["TreeSitterPython"]),
        .library(name: "TreeSitterRegex", targets: ["TreeSitterRegex"]),
        .library(name: "TreeSitterRuby", targets: ["TreeSitterRuby"]),
        .library(name: "TreeSitterRust", targets: ["TreeSitterRust"]),
        .library(name: "TreeSitterSwift", targets: ["TreeSitterSwift"]),
        .library(name: "TreeSitterTypeScript", targets: ["TreeSitterTypeScript"]),
        .library(name: "TreeSitterXML", targets: ["TreeSitterXML"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tree-sitter/tree-sitter", .upToNextMinor(from: "0.25.0")),
    ],
    targets: [
        grammarTarget(name: "TreeSitterBash", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterC", sources: ["parser.c"]),
        grammarTarget(name: "TreeSitterCPP", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterCSharp", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterCSS", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterGo", sources: ["parser.c"]),
        grammarTarget(name: "TreeSitterHTML", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterJavaScript", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterJSON", sources: ["parser.c"]),
        grammarTarget(name: "TreeSitterPython", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterRegex", sources: ["parser.c"]),
        grammarTarget(name: "TreeSitterRuby", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterRust", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterSwift", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterTypeScript", sources: ["parser.c", "scanner.c"]),
        grammarTarget(name: "TreeSitterXML", sources: ["parser.c", "scanner.c"]),
    ],
    cLanguageStandard: .c11
)

private func grammarTarget(name: String, sources: [String]) -> Target {
    .target(
        name: name,
        dependencies: [
            .product(name: "TreeSitter", package: "tree-sitter"),
        ],
        path: "Sources/\(name)",
        sources: sources,
        publicHeadersPath: "include",
        cSettings: [
            .headerSearchPath("."),
        ]
    )
}
