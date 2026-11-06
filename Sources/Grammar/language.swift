public enum Grammar {}

public extension Grammar {
    struct Language: Sendable, Codable, Equatable {
        public let name: String
        public let start: String
        public let productions: [Production]
        public let terminals: [Terminal]
        public let extras: [Expression]
        public let word: String?
        public let highlights: [Highlight]

        public init(
            name: String,
            start: String,
            productions: [Production],
            terminals: [Terminal] = [],
            extras: [Expression] = [],
            word: String? = nil,
            highlights: [Highlight] = []
        ) throws {
            self.name = name
            self.start = start
            self.productions = productions
            self.terminals = terminals
            self.extras = extras
            self.word = word
            self.highlights = highlights
            _ = try analyze()
        }

        public func analyze() throws -> Analysis {
            try Analyzer.inspect(self)
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                name: values.decode(String.self, forKey: .name),
                start: values.decode(String.self, forKey: .start),
                productions: values.decode([Production].self, forKey: .productions),
                terminals: values.decodeIfPresent([Terminal].self, forKey: .terminals) ?? [],
                extras: values.decodeIfPresent([Expression].self, forKey: .extras) ?? [],
                word: values.decodeIfPresent(String.self, forKey: .word),
                highlights: values.decodeIfPresent([Highlight].self, forKey: .highlights) ?? []
            )
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case start
            case productions
            case terminals
            case extras
            case word
            case highlights
        }
    }
}
