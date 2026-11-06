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
        let contextual = try language.highlights.map { highlight in
            switch highlight {
            case .field(let production, let name, let role):
                return "(\(production) \(name): (_) @\(role))"
            case .symbol(let symbol, let within, let role):
                return "(\(within) (\(symbol.name)) @\(role))"
            case .literal(let value, let role):
                let token = try JSONValue.string(value).toJSONString(prettyPrinted: false)
                return "\(token) @\(role)"
            }
        }
        return (productions + terminals + contextual).sorted().joined(separator: "\n") + "\n"
    }
}
