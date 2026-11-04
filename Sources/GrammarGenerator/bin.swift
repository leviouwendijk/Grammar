import Foundation
import Grammar
import GrammarTreeSitter

@main
struct GrammarGenerator {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard (2...3).contains(arguments.count),
              arguments.count == 2 || arguments[2] == "--compile" else {
            throw Failure.usage
        }

        let definition = URL(fileURLWithPath: arguments[0])
        let destination = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let input = try Data(contentsOf: definition)
        let language = try JSONDecoder().decode(Grammar.Language.self, from: input)
        let artifacts = try GrammarTreeSitter.emit(language)
        let sourceDirectory = destination.appendingPathComponent("src", isDirectory: true)
        let queryDirectory = destination.appendingPathComponent("queries", isDirectory: true)
        let files = FileManager.default

        try files.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try files.createDirectory(at: queryDirectory, withIntermediateDirectories: true)
        try artifacts.grammarJSON.write(
            to: sourceDirectory.appendingPathComponent("grammar.json"),
            atomically: true,
            encoding: .utf8
        )
        for (name, contents) in artifacts.queries {
            try contents.write(
                to: queryDirectory.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }

        if arguments.count == 3 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["tree-sitter", "generate", "src/grammar.json"]
            process.currentDirectoryURL = destination
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw Failure.compiler(process.terminationStatus)
            }
        }
    }

    enum Failure: Swift.Error {
        case usage
        case compiler(Int32)
    }
}
