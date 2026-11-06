import Foundation
import Grammar
import GrammarTreeSitter
import Testing

@main
struct GrammarTests {
    static func main() async throws {
        let suite = TestSuite("grammar") {
            Test("recursive_grammar_analysis") {
                let language = try ArithmeticGrammar.language()
                let analysis = try language.analyze()
                try Expect.true(
                    analysis.left_recursive.contains("expression"),
                    "Expression recursion is detected"
                )
                try Expect.true(
                    analysis.left_recursive.contains("binary_expression"),
                    "Indirect recursion is detected"
                )
                try Expect.true(analysis.unreachable.isEmpty, "All productions are reachable")
            }
            Test("canonical_language_symbol_lookups") {
                let language = try ArithmeticGrammar.language()
                try Expect.equal(language.production(named: "expression")?.name,
                                 "expression", "production lookup")
                try Expect.equal(language.terminal(named: "identifier")?.name,
                                 "identifier", "terminal lookup")
                try Expect.equal(language.production(named: "missing")?.name, nil,
                                 "missing production")
            }
            Test("reject_undefined_symbol") {
                do {
                    _ = try Grammar.Language(
                        name: "broken",
                        start: "source_file",
                        productions: [
                            .init(
                                name: "source_file",
                                expression: .symbol(.production("missing"))
                            )
                        ]
                    )
                    throw Failure.unexpected_acceptance
                } catch Grammar.Error.undefined_symbol(.production("missing")) {}
            }
            Test("reject_nullable_repetition") {
                do {
                    _ = try Grammar.Language(
                        name: "broken",
                        start: "source_file",
                        productions: [
                            .init(
                                name: "source_file",
                                expression: .repeat0(.optional(.literal("x")))
                            )
                        ]
                    )
                    throw Failure.unexpected_acceptance
                } catch Grammar.Error.nullable_repetition {}
            }
            Test("highlighting declarations are typed, validated, and Codable") {
                let language = try ArithmeticGrammar.language()
                let data = try JSONEncoder().encode(language)
                let decoded = try JSONDecoder().decode(Grammar.Language.self, from: data)
                try Expect.equal(decoded.highlights, language.highlights, "round-trip captures")
                try Expect.throwsError("unknown field cannot be highlighted") {
                    _ = try Grammar.Language(
                        name: "invalid_highlighting",
                        start: "document",
                        productions: [.init(name: "document", expression: .literal("x"))],
                        highlights: [.field(production: "document", name: "missing", role: "property")]
                    )
                }
                try Expect.throwsError("unknown literal cannot be highlighted") {
                    _ = try Grammar.Language(
                        name: "invalid_highlighting",
                        start: "document",
                        productions: [.init(name: "document", expression: .literal("x"))],
                        highlights: [.literal("y", role: "operator")]
                    )
                }
            }
            Test("conditional_highlighting_selectors_are_validated_and_codable") {
                let base = try ArithmeticGrammar.language()
                let extra: [Grammar.Highlight] = [
                    .matching(
                        selector: .node(.terminal("identifier")),
                        text: .any_of(["result", "counter"]),
                        role: "variable.builtin",
                        priority: 120
                    ),
                    .matching(
                        selector: .node(.terminal("identifier")),
                        text: .matches("^[A-Z_]+$"),
                        role: "constant",
                        priority: 110
                    )
                ]
                let combined = try base.addingHighlights(extra)
                let encoded = try JSONEncoder().encode(combined)
                let decoded = try JSONDecoder().decode(Grammar.Language.self, from: encoded)
                try Expect.equal(decoded.highlights, combined.highlights, "Codable conditional highlighting")
                let queries = try GrammarTreeSitter.emit(base, additionalHighlights: extra).queries
                guard let source = queries["highlights.scm"] else { throw Failure.unexpected_acceptance }
                try Expect.true(source.contains("#any-of? @variable.builtin"), "generated membership predicate")
                try Expect.true(source.contains("#match? @constant"), "generated regular expression predicate")
                try Expect.true(source.contains("#set! priority 120"), "explicit capture priority")
                try Expect.throwsError("empty membership predicate") {
                    _ = try base.addingHighlights([
                        .matching(selector: .node(.terminal("identifier")), text: .any_of([]),
                                  role: "keyword", priority: 120)
                    ])
                }
                try Expect.throwsError("unknown selector") {
                    _ = try base.addingHighlights([
                        .matching(selector: .field(production: "missing", name: "name"),
                                  text: .equals("x"), role: "keyword", priority: 120)
                    ])
                }
                try Expect.throwsError("invalid priority") {
                    _ = try base.addingHighlights([
                        .matching(selector: .node(.terminal("identifier")),
                                  text: .equals("x"), role: "keyword", priority: -1)
                    ])
                }
            }
            Test("tree_sitter_grammar_emission_is_deterministic") {
                let language = try ArithmeticGrammar.language()
                let expected = try GrammarTreeSitter.emit(language)
                try Expect.true(
                    expected.grammarJSON.contains("\"rules\":{\"source_file\":"),
                    "start rule must remain first"
                )
                for _ in 0..<32 {
                    let actual = try GrammarTreeSitter.emit(language)
                    try Expect.equal(actual.grammarJSON, expected.grammarJSON, "stable grammar JSON")
                    try Expect.equal(actual.queries, expected.queries, "stable highlight queries")
                }
            }
            Test("tree_sitter_end_to_end") {
                try TreeSitterConformance.run()
            }
        }
        let reporter = PlainTextTestReporter(
            verbose: true,
            output: ClosureTestTextOutput { text in
                print(text, terminator: "")
            }
        )
        let result = await TestRunner.run(suite, sink: reporter)
        guard result.failureCount == 0 else {
            throw Failure.test_failures(result.failureCount)
        }
    }

    enum Failure: Swift.Error {
        case test_failures(Int)
        case unexpected_acceptance
    }
}

private enum TreeSitterConformance {
    static func run() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("grammar-conformance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let language = try ArithmeticGrammar.language()
        let artifacts = try GrammarTreeSitter.emit(language)
        let sourceDirectory = workspace.appendingPathComponent("src", isDirectory: true)
        let queryDirectory = workspace.appendingPathComponent("queries", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: queryDirectory, withIntermediateDirectories: true)
        try write(artifacts.grammarJSON, at: sourceDirectory.appendingPathComponent("grammar.json"))
        for (name, contents) in artifacts.queries {
            try write(contents, at: queryDirectory.appendingPathComponent(name))
        }

        let configuration = #"""
        {
            "grammars": [
                {
                    "name": "arithmetic",
                    "scope": "source.arithmetic",
                    "path": ".",
                    "file-types": ["arith"],
                    "highlights": "queries/highlights.scm"
                }
            ],
            "metadata": {
                "version": "0.1.0",
                "authors": [{"name": "Grammar Conformance"}]
            }
        }
        """#
        try write(configuration, at: workspace.appendingPathComponent("tree-sitter.json"))
        try write(#"{"name":"tree-sitter-arithmetic","version":"0.1.0"}"#, at: workspace.appendingPathComponent("package.json"))

        let valid = workspace.appendingPathComponent("valid.arith")
        let invalid = workspace.appendingPathComponent("invalid.arith")
        let associative = workspace.appendingPathComponent("associative.arith")
        try write("let result = a + b * (c + d) // comment\n", at: valid)
        try write("let result = a + * b\n", at: invalid)
        try write("let result = a + b + c\n", at: associative)

        let generate = try command(["generate", "src/grammar.json"], at: workspace)
        try requireSuccess(generate, stage: "tree-sitter generate")
        try Expect.true(
            FileManager.default.fileExists(atPath: sourceDirectory.appendingPathComponent("parser.c").path),
            "Tree-sitter generated parser.c"
        )
        try Expect.true(
            FileManager.default.fileExists(atPath: sourceDirectory.appendingPathComponent("node-types.json").path),
            "Tree-sitter generated node-types.json"
        )

        let parsed = try command(["parse", "--grammar-path", workspace.path, valid.path], at: workspace)
        try requireSuccess(parsed, stage: "parse valid arithmetic")
        try Expect.true(parsed.output.contains("binary_expression"), "A binary-expression syntax node was parsed")
        try Expect.false(parsed.output.contains("(ERROR"), "Valid input contains no ERROR nodes")
        try Expect.false(parsed.output.contains("(MISSING"), "Valid input contains no MISSING nodes")

        let broken = try command(["parse", "--grammar-path", workspace.path, invalid.path], at: workspace)
        try Expect.true(broken.status != 0, "Invalid arithmetic must produce a parse failure")
        try Expect.true(
            broken.output.contains("ERROR") || broken.output.contains("MISSING"),
            "Invalid arithmetic produces syntax-error evidence"
        )

        let shapeQuery = workspace.appendingPathComponent("shape.scm")
        try write(
            #"""
            (binary_expression
              left: (expression (identifier))
              right: (expression (binary_expression))) @multiplication_inside_add
            (parenthesized_expression
              inner: (expression (binary_expression))) @parenthesized_add
            """#,
            at: shapeQuery
        )
        let shape = try command(
            ["query", "--grammar-path", workspace.path, shapeQuery.path, valid.path],
            at: workspace
        )
        try requireSuccess(shape, stage: "query precedence and parentheses")
        try Expect.true(shape.output.contains("multiplication_inside_add"), "Multiplication binds inside addition")
        try Expect.true(shape.output.contains("parenthesized_add"), "Parentheses preserve nested addition")

        let associativityQuery = workspace.appendingPathComponent("associativity.scm")
        try write(
            #"""
            (binary_expression
              left: (expression (binary_expression))
              right: (expression (identifier))) @left_associative_addition
            """#,
            at: associativityQuery
        )
        let association = try command(
            ["query", "--grammar-path", workspace.path, associativityQuery.path, associative.path],
            at: workspace
        )
        try requireSuccess(association, stage: "query left associativity")
        try Expect.true(association.output.contains("left_associative_addition"), "Addition associates to the left")

        let highlighted = try command(
            ["query", "--grammar-path", workspace.path,
             queryDirectory.appendingPathComponent("highlights.scm").path, valid.path],
            at: workspace
        )
        try requireSuccess(highlighted, stage: "query generated highlights")
        try Expect.true(highlighted.output.contains("capture: "), "The highlight query returned captures")
        for capture in ["keyword", "variable", "comment", "property", "operator", "punctuation.bracket"] {
            try Expect.true(highlighted.output.contains(capture), "The \(capture) capture was returned")
        }
    }

    private static func write(_ contents: String, at destination: URL) throws {
        try contents.write(to: destination, atomically: true, encoding: .utf8)
    }

    private static func requireSuccess(_ result: CommandResult, stage: String) throws {
        guard result.status == 0 else {
            throw Failure.command_failed(stage, result.status, result.output)
        }
    }

    private static func command(_ arguments: [String], at workspace: URL) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tree-sitter"] + arguments
        process.currentDirectoryURL = workspace
        let stream = Pipe()
        process.standardOutput = stream
        process.standardError = stream
        try process.run()
        process.waitUntilExit()
        let data = stream.fileHandleForReading.readDataToEndOfFile()
        return .init(
            status: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self)
        )
    }

    private struct CommandResult {
        let status: Int32
        let output: String
    }

    private enum Failure: Swift.Error, CustomStringConvertible {
        case command_failed(String, Int32, String)

        var description: String {
            switch self {
            case .command_failed(let stage, let status, let output):
                "\(stage) failed (status \(status)):\n\(output)"
            }
        }
    }
}
