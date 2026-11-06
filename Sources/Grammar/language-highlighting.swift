public extension Grammar.Language {
    /// Add consumer-specific classifications without changing grammar recognition.
    /// Reconstructing the language validates all combined declarations.
    func addingHighlights(_ additions: [Grammar.Highlight]) throws -> Self {
        try Self.init(
            name: name,
            start: start,
            productions: productions,
            terminals: terminals,
            extras: extras,
            word: word,
            highlights: highlights + additions
        )
    }
}
