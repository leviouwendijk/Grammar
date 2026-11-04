public extension Grammar {
    struct Terminal: Sendable, Codable, Equatable {
        public let name: String
        public let pattern: Pattern
        public let lexicalPriority: Int
        public let role: String?

        public init(
            name: String,
            pattern: Pattern,
            lexicalPriority: Int = 0,
            role: String? = nil
        ) {
            self.name = name
            self.pattern = pattern
            self.lexicalPriority = lexicalPriority
            self.role = role
        }
    }
}
