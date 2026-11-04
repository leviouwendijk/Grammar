import Grammar
import Primitives

enum TreeSitterLowering {
    static func rule(
        _ expression: Grammar.Expression,
        names: [String: String]
    ) -> JSONValue {
        switch expression {
        case .blank:
            return .object(["type": .string("BLANK")])
        case .literal(let value):
            return .object(["type": .string("STRING"), "value": .string(value)])
        case .pattern(let value):
            return .object(["type": .string("PATTERN"), "value": .string(value)])
        case .symbol(let symbol):
            return .object([
                "type": .string("SYMBOL"),
                "name": .string(symbolName(symbol, names: names))
            ])
        case .sequence(let members):
            return .object([
                "type": .string("SEQ"),
                "members": .array(members.map { rule($0, names: names) })
            ])
        case .choice(let members):
            return .object([
                "type": .string("CHOICE"),
                "members": .array(members.map { rule($0, names: names) })
            ])
        case .optional(let expression):
            return .object([
                "type": .string("CHOICE"),
                "members": .array([
                    rule(expression, names: names),
                    .object(["type": .string("BLANK")])
                ])
            ])
        case .repeat0(let expression):
            return .object([
                "type": .string("REPEAT"),
                "content": rule(expression, names: names)
            ])
        case .repeat1(let expression):
            return .object([
                "type": .string("REPEAT1"),
                "content": rule(expression, names: names)
            ])
        case .field(let name, let expression):
            return .object([
                "type": .string("FIELD"),
                "name": .string(name),
                "content": rule(expression, names: names)
            ])
        case .precedence(let value, let associativity, let expression):
            let kind: String
            switch associativity {
            case .none:
                kind = "PREC"
            case .left:
                kind = "PREC_LEFT"
            case .right:
                kind = "PREC_RIGHT"
            }
            return .object([
                "type": .string(kind),
                "value": .int(value),
                "content": rule(expression, names: names)
            ])
        }
    }

    static func terminal(_ terminal: Grammar.Terminal) -> JSONValue {
        let content: JSONValue
        switch terminal.pattern {
        case .literal(let value):
            content = .object(["type": .string("STRING"), "value": .string(value)])
        case .regex(let value):
            content = .object(["type": .string("PATTERN"), "value": .string(value)])
        }
        let prioritized: JSONValue
        if terminal.lexicalPriority == 0 {
            prioritized = content
        } else {
            prioritized = .object([
                "type": .string("PREC"),
                "value": .int(terminal.lexicalPriority),
                "content": content
            ])
        }
        return .object([
            "type": .string("TOKEN"),
            "content": prioritized
        ])
    }

    static func symbolName(_ symbol: Grammar.Symbol, names: [String: String]) -> String {
        switch symbol {
        case .production(let name):
            names[name] ?? name
        case .terminal(let name):
            name
        }
    }
}
