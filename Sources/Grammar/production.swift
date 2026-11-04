public extension Grammar {
    enum Visibility: String, Sendable, Codable, Equatable {
        case named
        case hidden
        case inline
    }

    struct Production: Sendable, Codable, Equatable {
        public let name: String
        public let expression: Expression
        public let visibility: Visibility
        public let role: String?

        public init(
            name: String,
            expression: Expression,
            visibility: Visibility = .named,
            role: String? = nil
        ) {
            self.name = name
            self.expression = expression
            self.visibility = visibility
            self.role = role
        }
    }
}
