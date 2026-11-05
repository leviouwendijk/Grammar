public extension Grammar.Language {
    /// Resolve the canonical definitions without constructing another grammar model.
    func production(named name: String) -> Grammar.Production? {
        productions.first { $0.name == name }
    }

    func terminal(named name: String) -> Grammar.Terminal? {
        terminals.first { $0.name == name }
    }
}
