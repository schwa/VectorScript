// How an element combines with what is already drawn behind it. The names and meanings are CSS mix-blend-mode's.
public enum BlendMode: String, Sendable, Equatable, Codable, CaseIterable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge = "color-dodge"
    case colorBurn = "color-burn"
    case hardLight = "hard-light"
    case softLight = "soft-light"
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity
}
