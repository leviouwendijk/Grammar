import Primitives

public extension Grammar {
    struct Analysis: Sendable, Equatable {
        public let nullable: Set<String>
        public let left_recursive: Set<String>
        public let unreachable: Set<String>
    }

    enum Error: Swift.Error, Sendable, Equatable {
        case invalid_name(String)
        case duplicate_symbol(String)
        case undefined_symbol(Symbol)
        case missing_start(String)
        case invalid_expression(String)
        case nullable_repetition
    }
}

enum Analyzer {
    private typealias ReferenceGraph = Graph<String, Bool, Int, Bool>

    static func inspect(_ language: Grammar.Language) throws -> Grammar.Analysis {
        guard validName(language.name) else {
            throw Grammar.Error.invalid_name(language.name)
        }

        var seen: Set<String> = []
        for production in language.productions {
            try register(production.name, in: &seen)
            if let role = production.role, !validRole(role) {
                throw Grammar.Error.invalid_name(role)
            }
        }
        for terminal in language.terminals {
            try register(terminal.name, in: &seen)
            if let role = terminal.role, !validRole(role) {
                throw Grammar.Error.invalid_name(role)
            }
            switch terminal.pattern {
            case .literal(let value), .regex(let value):
                guard !value.isEmpty else {
                    throw Grammar.Error.invalid_expression(terminal.name)
                }
            }
        }

        guard language.productions.contains(where: { $0.name == language.start }) else {
            throw Grammar.Error.missing_start(language.start)
        }
        if let word = language.word,
           !language.terminals.contains(where: { $0.name == word }) {
            throw Grammar.Error.undefined_symbol(.terminal(word))
        }

        let productionNames = Set(language.productions.map(\.name))
        let terminalNames = Set(language.terminals.map(\.name))
        let expressions = language.productions.map(\.expression) + language.extras

        for expression in expressions {
            try check(
                expression,
                productions: productionNames,
                terminals: terminalNames
            )
        }

        var nullable: Set<String> = []
        var changed = true
        while changed {
            changed = false
            for production in language.productions where !nullable.contains(production.name) {
                if isNullable(production.expression, nullable: nullable) {
                    nullable.insert(production.name)
                    changed = true
                }
            }
        }
        for expression in expressions {
            try checkRepetition(expression, nullable: nullable)
        }

        let referenceGraph = try graph(language, references: references)
        let leadingGraph = try graph(language) {
            firstReferences($0, nullable: nullable)
        }

        let reachable = Set(try referenceGraph.walk(starting_at: language.start))
        var leftRecursive: Set<String> = []
        for production in language.productions {
            let name = production.name
            for edge in leadingGraph.index.outgoing_edges(from: name) {
                let path = try leadingGraph.walk(starting_at: edge.destination)
                if path.contains(name) {
                    leftRecursive.insert(name)
                    break
                }
            }
        }

        return .init(
            nullable: nullable,
            left_recursive: leftRecursive,
            unreachable: productionNames.subtracting(reachable)
        )
    }

    private static func graph(
        _ language: Grammar.Language,
        references: (Grammar.Expression) -> Set<String>
    ) throws -> ReferenceGraph {
        let nodes: [ReferenceGraph.Node] = language.productions.map {
            .init(id: $0.name, value: true)
        }
        var edges: [ReferenceGraph.Edge] = []
        for production in language.productions {
            for name in references(production.expression).sorted() {
                edges.append(
                    .init(
                        id: edges.count,
                        source: production.name,
                        destination: name,
                        value: true
                    )
                )
            }
        }
        return try ReferenceGraph(nodes: nodes, edges: edges)
    }

    private static func register(_ name: String, in seen: inout Set<String>) throws {
        guard validName(name) else {
            throw Grammar.Error.invalid_name(name)
        }
        guard seen.insert(name).inserted else {
            throw Grammar.Error.duplicate_symbol(name)
        }
    }

    private static func validName(_ value: String) -> Bool {
        guard let first = value.utf8.first,
              first == 95 || (65...90).contains(first) || (97...122).contains(first) else {
            return false
        }
        return value.utf8.dropFirst().allSatisfy {
            $0 == 95 || (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
        }
    }

    private static func validRole(_ value: String) -> Bool {
        !value.isEmpty && value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy {
            validName(String($0))
        }
    }

    private static func check(
        _ expression: Grammar.Expression,
        productions: Set<String>,
        terminals: Set<String>
    ) throws {
        switch expression {
        case .blank:
            break
        case .literal(let value), .pattern(let value):
            guard !value.isEmpty else {
                throw Grammar.Error.invalid_expression("empty lexical match")
            }
        case .symbol(let symbol):
            switch symbol {
            case .production(let name) where productions.contains(name):
                break
            case .terminal(let name) where terminals.contains(name):
                break
            default:
                throw Grammar.Error.undefined_symbol(symbol)
            }
        case .sequence(let children), .choice(let children):
            guard !children.isEmpty else {
                throw Grammar.Error.invalid_expression("empty sequence or choice")
            }
            for child in children {
                try check(child, productions: productions, terminals: terminals)
            }
        case .optional(let child), .repeat0(let child), .repeat1(let child), .precedence(_, _, let child):
            try check(child, productions: productions, terminals: terminals)
        case .field(let name, let child):
            guard validName(name) else {
                throw Grammar.Error.invalid_name(name)
            }
            try check(child, productions: productions, terminals: terminals)
        }
    }

    private static func isNullable(_ expression: Grammar.Expression, nullable: Set<String>) -> Bool {
        switch expression {
        case .blank, .optional, .repeat0:
            true
        case .literal, .pattern, .symbol(.terminal):
            false
        case .symbol(.production(let name)):
            nullable.contains(name)
        case .sequence(let children):
            children.allSatisfy { isNullable($0, nullable: nullable) }
        case .choice(let children):
            children.contains { isNullable($0, nullable: nullable) }
        case .repeat1(let child), .field(_, let child), .precedence(_, _, let child):
            isNullable(child, nullable: nullable)
        }
    }

    private static func checkRepetition(
        _ expression: Grammar.Expression,
        nullable: Set<String>
    ) throws {
        switch expression {
        case .repeat0(let child), .repeat1(let child):
            guard !isNullable(child, nullable: nullable) else {
                throw Grammar.Error.nullable_repetition
            }
            try checkRepetition(child, nullable: nullable)
        case .sequence(let children), .choice(let children):
            for child in children {
                try checkRepetition(child, nullable: nullable)
            }
        case .optional(let child), .field(_, let child), .precedence(_, _, let child):
            try checkRepetition(child, nullable: nullable)
        default:
            break
        }
    }

    private static func references(_ expression: Grammar.Expression) -> Set<String> {
        switch expression {
        case .symbol(.production(let name)):
            [name]
        case .sequence(let children), .choice(let children):
            children.reduce(into: Set<String>()) { $0.formUnion(references($1)) }
        case .optional(let child), .repeat0(let child), .repeat1(let child), .field(_, let child), .precedence(_, _, let child):
            references(child)
        default:
            []
        }
    }

    private static func firstReferences(
        _ expression: Grammar.Expression,
        nullable: Set<String>
    ) -> Set<String> {
        switch expression {
        case .symbol(.production(let name)):
            return [name]

        case .sequence(let children):
            var result: Set<String> = []
            for child in children {
                result.formUnion(firstReferences(child, nullable: nullable))
                if !isNullable(child, nullable: nullable) {
                    break
                }
            }
            return result

        case .choice(let children):
            return children.reduce(into: Set<String>()) {
                $0.formUnion(firstReferences($1, nullable: nullable))
            }

        case .optional(let child), .repeat0(let child), .repeat1(let child), .field(_, let child), .precedence(_, _, let child):
            return firstReferences(child, nullable: nullable)

        default:
            return []
        }
    }
}
