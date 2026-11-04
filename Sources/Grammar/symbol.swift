public extension Grammar {
    enum Symbol: Sendable, Codable, Equatable, Hashable {
        case production(String)
        case terminal(String)

        public var name: String {
            switch self {
            case .production(let name), .terminal(let name):
                name
            }
        }
    }
}
