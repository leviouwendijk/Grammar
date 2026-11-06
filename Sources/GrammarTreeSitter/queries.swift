import Grammar
import Primitives

enum TreeSitterQueries {
    static func highlights(_ language: Grammar.Language) throws -> String {
        let productions = language.productions.compactMap { production -> String? in
            guard let role = production.role, production.visibility == .named else {
                return nil
            }
            return "(\(production.name)) @\(role)"
        }
        let terminals = language.terminals.compactMap { terminal -> String? in
            guard let role = terminal.role else {
                return nil
            }
            return "(\(terminal.name)) @\(role)"
        }
        let contextual = try language.highlights.map { highlight -> String in
            switch highlight {
            case .field(let production, let name, let role):
                return "(\(production) \(name): (_) @\(role))"
            case .symbol(let symbol, let within, let role):
                return "(\(within) (\(symbol.name)) @\(role))"
            case .literal(let value, let role):
                return "\(try quoted(value)) @\(role)"
            case .matching(let selector, let text, let role, let priority):
                let capture = "@\(role)"
                let pattern: String
                switch selector {
                case .field(let production, let name):
                    pattern = "(\(production) \(name): (_) \(capture))"
                case .symbol(let symbol, let within):
                    pattern = "(\(within) (\(symbol.name)) \(capture))"
                case .node(let symbol):
                    pattern = "(\(symbol.name)) \(capture)"
                }
                let condition: String
                switch text {
                case .equals(let value):
                    condition = "(#eq? \(capture) \(try quoted(value)))"
                case .any_of(let values):
                    let arguments = try values.map(quoted).joined(separator: " ")
                    condition = "(#any-of? \(capture) \(arguments))"
                case .matches(let expression):
                    condition = "(#match? \(capture) \(try quoted(expression)))"
                }
                return "(\(pattern)\n  \(condition)\n  (#set! priority \(priority)))"
            }
        }
        return (productions + terminals + contextual).sorted().joined(separator: "\n") + "\n"
    }

    private static func quoted(_ value: String) throws -> String {
        try JSONValue.string(value).toJSONString(prettyPrinted: false)
    }
}
