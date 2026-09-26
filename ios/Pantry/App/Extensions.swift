extension Array {
    /// `removeLast()` traps on an empty array; navigation-path pops should
    /// just no-op instead (e.g. a screen shown standalone by the debug host).
    mutating func safePop() {
        if !isEmpty { removeLast() }
    }
}
