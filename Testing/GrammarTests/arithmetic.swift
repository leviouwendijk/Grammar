import Grammar

enum ArithmeticGrammar {
    static func language() throws -> Grammar.Language {
        let expression: Grammar.Expression = .symbol(.production("expression"))
        let identifier: Grammar.Expression = .symbol(.terminal("identifier"))
        let binary: Grammar.Expression = .symbol(.production("binary_expression"))

        func infix(_ operatorText: String, precedence: Int) -> Grammar.Expression {
            .precedence(precedence, .left, .sequence([
                .field("left", expression),
                .literal(operatorText),
                .field("right", expression)
            ]))
        }

        return try Grammar.Language(
            name: "arithmetic",
            start: "source_file",
            productions: [
                .init(
                    name: "source_file",
                    expression: .repeat1(.symbol(.production("declaration")))
                ),
                .init(
                    name: "declaration",
                    expression: .sequence([
                        .symbol(.terminal("let_keyword")),
                        .field("name", identifier),
                        .literal("="),
                        .field("value", expression)
                    ])
                ),
                .init(
                    name: "expression",
                    expression: .choice([
                        binary,
                        .symbol(.production("parenthesized_expression")),
                        identifier
                    ])
                ),
                .init(
                    name: "binary_expression",
                    expression: .choice([
                        infix("+", precedence: 1),
                        infix("*", precedence: 2)
                    ])
                ),
                .init(
                    name: "parenthesized_expression",
                    expression: .sequence([
                        .literal("("),
                        .field("inner", expression),
                        .literal(")")
                    ])
                )
            ],
            terminals: [
                .init(name: "let_keyword", pattern: .literal("let"), role: "keyword"),
                .init(name: "identifier", pattern: .regex("[a-z_][a-z0-9_]*"), role: "variable"),
                .init(name: "comment", pattern: .regex("//[^\\r\\n]*"), role: "comment")
            ],
            extras: [
                .pattern("\\s+"),
                .symbol(.terminal("comment"))
            ],
            word: "identifier"
        )
    }
}
