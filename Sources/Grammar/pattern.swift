public extension Grammar {
    enum Pattern: Sendable, Codable, Equatable {
        case literal(String)
        case regex(String)
    }
}
