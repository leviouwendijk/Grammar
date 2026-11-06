enum HighlightAnalysis {
    static func check(_ language: Grammar.Language) throws {
        for highlight in language.highlights {
            switch highlight {
            case .field(let production, let name, let role):
                try checkRole(role)
                try checkSelector(.field(production: production, name: name), in: language)
            case .symbol(let symbol, let within, let role):
                try checkRole(role)
                try checkSelector(.symbol(symbol, within: within), in: language)
            case .literal(let literal, let role):
                try checkRole(role)
                guard language.productions.contains(where: { production in
                    contains(production.expression, where: { expression in
                        if case .literal(let candidate) = expression { return candidate == literal }
                        return false
                    })
                }) else {
                    throw Grammar.Error.invalid_highlight("Unknown literal \(literal)")
                }
            case .matching(let selector, let text, let role, let priority):
                try checkRole(role)
                try checkSelector(selector, in: language)
                guard priority >= 0 else {
                    throw Grammar.Error.invalid_highlight("Negative capture priority \(priority)")
                }
                switch text {
                case .equals(let value), .matches(let value):
                    guard !value.isEmpty else {
                        throw Grammar.Error.invalid_highlight("Empty text predicate")
                    }
                case .any_of(let values):
                    guard !values.isEmpty, values.allSatisfy({ !$0.isEmpty }) else {
                        throw Grammar.Error.invalid_highlight("Empty text alternative")
                    }
                }
            }
        }
    }

    private static func checkSelector(
        _ selector: Grammar.Highlight.Selector,
        in language: Grammar.Language
    ) throws {
        switch selector {
        case .field(let production, let name):
            guard let parent = language.production(named: production),
                  parent.visibility == .named,
                  contains(parent.expression, where: { expression in
                      if case .field(let field, _) = expression { return field == name }
                      return false
                  }) else {
                throw Grammar.Error.invalid_highlight("Unknown field \(production).\(name)")
            }
        case .symbol(let symbol, let within):
            guard let parent = language.production(named: within),
                  parent.visibility == .named,
                  contains(parent.expression, where: { expression in
                      if case .symbol(let candidate) = expression { return candidate == symbol }
                      return false
                  }),
                  named(symbol, in: language) else {
                throw Grammar.Error.invalid_highlight("Invalid symbol \(symbol.name) in \(within)")
            }
        case .node(let symbol):
            guard named(symbol, in: language) else {
                throw Grammar.Error.invalid_highlight("Unknown named symbol \(symbol.name)")
            }
        }
    }

    private static func checkRole(_ role: String) throws {
        guard Analyzer.validRole(role) else {
            throw Grammar.Error.invalid_highlight("Invalid capture role \(role)")
        }
    }

    private static func named(_ symbol: Grammar.Symbol, in language: Grammar.Language) -> Bool {
        switch symbol {
        case .terminal(let name):
            return language.terminal(named: name) != nil
        case .production(let name):
            return language.production(named: name)?.visibility == .named
        }
    }

    private static func contains(
        _ expression: Grammar.Expression,
        where predicate: (Grammar.Expression) -> Bool
    ) -> Bool {
        if predicate(expression) { return true }
        switch expression {
        case .sequence(let children), .choice(let children):
            return children.contains { contains($0, where: predicate) }
        case .optional(let child), .repeat0(let child), .repeat1(let child),
             .field(_, let child), .precedence(_, _, let child):
            return contains(child, where: predicate)
        default:
            return false
        }
    }
}
