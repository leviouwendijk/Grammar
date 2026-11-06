import Foundation
import Grammar
import Primitives

public enum GrammarTreeSitter {
    public enum Error: Swift.Error, Sendable, Equatable {
        case invalid_start_visibility(String)
        case conflicting_emitted_name(String)
    }

    public struct Artifacts: Sendable {
        public let grammarJSON: String
        public let queries: [String: String]
    }

    public static func emit(_ language: Grammar.Language) throws -> Artifacts {
        _ = try language.analyze()

        let names = Dictionary(uniqueKeysWithValues: language.productions.map {
            ($0.name, $0.visibility == .hidden ? "_\($0.name)" : $0.name)
        })
        let emittedNames = language.productions.compactMap { names[$0.name] }
            + language.terminals.map(\.name)
        var seen: Set<String> = []
        for name in emittedNames {
            guard seen.insert(name).inserted else {
                throw Error.conflicting_emitted_name(name)
            }
        }
        guard language.productions.first(where: { $0.name == language.start })?.visibility == .named else {
            throw Error.invalid_start_visibility(language.start)
        }

        // Tree-sitter treats the first grammar rule as the start production.
        guard let start = language.productions.first(where: { $0.name == language.start }) else {
            throw Grammar.Error.missing_start(language.start)
        }
        let productions = [start] + language.productions.filter { $0.name != language.start }
        let entries: [(String, JSONValue)] = productions.map { production in
            (
                names[production.name] ?? production.name,
                TreeSitterLowering.rule(production.expression, names: names)
            )
        } + language.terminals.map { terminal in
            (terminal.name, TreeSitterLowering.terminal(terminal))
        }

        let members = try entries.map { name, value in
            let key = try JSONValue.string(name).toJSONString(prettyPrinted: false)
            let content = try sortedJSON(value)
            return "\(key):\(content)"
        }.joined(separator: ",")

        var fields: [String] = [
            "\"name\":\(try JSONValue.string(language.name).toJSONString(prettyPrinted: false))",
            "\"rules\":{\(members)}"
        ]
        if !language.extras.isEmpty {
            let extras = language.extras.map { TreeSitterLowering.rule($0, names: names) }
            fields.append("\"extras\":\(try sortedJSON(.array(extras)))")
        }
        if let word = language.word {
            fields.append("\"word\":\(try JSONValue.string(word).toJSONString(prettyPrinted: false))")
        }
        let inline = language.productions.filter { $0.visibility == .inline }
            .compactMap { names[$0.name] }
        if !inline.isEmpty {
            fields.append("\"inline\":\(try JSONValue.array(inline.map(JSONValue.string)).toJSONString(prettyPrinted: false))")
        }

        return Artifacts(
            grammarJSON: "{\(fields.joined(separator: ","))}\n",
            queries: ["highlights.scm": try TreeSitterQueries.highlights(language)]
        )
    }

    /// Sort nested JSON keys without changing the outer Tree-sitter start-rule order.
    private static func sortedJSON(_ value: JSONValue) throws -> String {
        let original = try value.toJSONString(prettyPrinted: false)
        let decoded = try JSONSerialization.jsonObject(
            with: Data(original.utf8),
            options: [.fragmentsAllowed]
        )
        let canonical = try JSONSerialization.data(
            withJSONObject: decoded,
            options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: canonical, as: UTF8.self)
    }
}
