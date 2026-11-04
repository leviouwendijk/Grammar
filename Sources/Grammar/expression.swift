public extension Grammar {
    indirect enum Expression: Sendable, Codable, Equatable {
        case blank
        case literal(String)
        case pattern(String)
        case symbol(Symbol)
        case sequence([Expression])
        case choice([Expression])
        case optional(Expression)
        case repeat0(Expression)
        case repeat1(Expression)
        case field(String, Expression)
        case precedence(Int, Associativity, Expression)
    }
}
