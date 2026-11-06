public extension Grammar {
    enum Highlight: Sendable, Codable, Equatable {
        case field(production: String, name: String, role: String)
        case symbol(Symbol, within: String, role: String)
        case literal(String, role: String)
    }
}
