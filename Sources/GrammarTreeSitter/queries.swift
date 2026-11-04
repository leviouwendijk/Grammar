import Grammar

enum TreeSitterQueries {
    static func highlights(_ language: Grammar.Language) -> String {
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
        return (productions + terminals).sorted().joined(separator: "\n") + "\n"
    }
}
