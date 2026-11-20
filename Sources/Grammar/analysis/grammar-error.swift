import Errors

extension Grammar.Error:
    SemanticError,
    ErrorNamespaced,
    ErrorDispositionProviding
{
    public static let errorNamespace = "grammar"

    public var errorCode: String {
        switch self {
        case .invalid_name: return "invalid_name"
        case .duplicate_symbol: return "duplicate_symbol"
        case .undefined_symbol: return "undefined_symbol"
        case .missing_start: return "missing_start"
        case .invalid_expression: return "invalid_expression"
        case .nullable_repetition: return "nullable_repetition"
        case .invalid_highlight: return "invalid_highlight"
        }
    }

    public var errorPresentation: ErrorPresentation {
        switch self {
        case .invalid_name(let name):
            return .init(
                message: "'\(name)' is not a valid grammar name.",
                reason: "A name starts with a letter or _ and holds only letters, digits and _; a role joins names with dots."
            )
        case .duplicate_symbol(let name):
            return .init(
                message: "'\(name)' is declared more than once.",
                reason: "Productions and terminals share one namespace."
            )
        case .undefined_symbol(let symbol):
            return .init(
                message: "The \(symbol.kind) '\(symbol.name)' is used but not declared."
            )
        case .missing_start(let name):
            return .init(
                message: "The start production '\(name)' is not declared."
            )
        case .invalid_expression(let detail):
            return .init(
                message: "The grammar holds an expression that can match nothing.",
                reason: detail
            )
        case .nullable_repetition:
            return .init(
                message: "A repetition wraps an expression that can match empty input.",
                reason: "It would repeat forever without consuming input.",
                recoverySuggestion: "Make the repeated expression consume at least one token."
            )
        case .invalid_highlight(let detail):
            return .init(
                message: "A highlight rule does not fit the grammar.",
                reason: detail
            )
        }
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        switch self {
        case .invalid_name(let name), .duplicate_symbol(let name), .missing_start(let name):
            return [.init(key: "grammar.symbol", value: name)]
        case .undefined_symbol(let symbol):
            return [.init(key: "grammar.symbol", value: symbol.name)]
        case .invalid_expression, .nullable_repetition, .invalid_highlight:
            return []
        }
    }

    /// A grammar is code: it holds until its definition changes.
    public var errorDisposition: ErrorDisposition? {
        .permanent
    }
}

private extension Grammar.Symbol {
    var kind: String {
        switch self {
        case .production: "production"
        case .terminal: "terminal"
        }
    }
}
