import Errors

extension GrammarTreeSitter.Error:
    SemanticError,
    ErrorNamespaced,
    ErrorDispositionProviding
{
    public static let errorNamespace = "grammar.tree_sitter"

    public var errorCode: String {
        switch self {
        case .invalid_start_visibility: return "invalid_start_visibility"
        case .conflicting_emitted_name: return "conflicting_emitted_name"
        }
    }

    public var errorPresentation: ErrorPresentation {
        switch self {
        case .invalid_start_visibility(let name):
            return .init(
                message: "The start production '\(name)' must be named to emit a Tree-sitter grammar.",
                reason: "Tree-sitter needs the start rule to be a visible node."
            )
        case .conflicting_emitted_name(let name):
            return .init(
                message: "Two rules would both be emitted as '\(name)'.",
                reason: "A hidden production is emitted with a leading _, which can collide with another rule."
            )
        }
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        switch self {
        case .invalid_start_visibility(let name), .conflicting_emitted_name(let name):
            return [.init(key: "grammar.symbol", value: name)]
        }
    }

    public var errorDisposition: ErrorDisposition? {
        .permanent
    }
}
