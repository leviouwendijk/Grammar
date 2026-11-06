extension Grammar {
    public enum Highlight: Sendable, Codable, Equatable {
        case field(production: String, name: String, role: String)
        case symbol(Symbol, within: String, role: String)
        case literal(String, role: String)
        case matching(selector: Selector, text: Text, role: String, priority: Int)

        public enum Selector: Sendable, Codable, Equatable {
            case field(production: String, name: String)
            case symbol(Symbol, within: String)
            case node(Symbol)
        }

        public enum Text: Sendable, Codable, Equatable {
            case equals(String)
            case any_of([String])
            case matches(String)
        }
    }
}
