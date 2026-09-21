import Foundation

public protocol ScaledUnit: RawRepresentable, CaseIterable, Identifiable where RawValue == String {
    var scale: Double { get }
}
public extension ScaledUnit { var id: String { rawValue } }
public enum ConcentrationUnit: String, ScaledUnit {
    case molar = "M", millimolar = "mM", micromolar = "μM"
    public var scale: Double { switch self { case .molar: return 1; case .millimolar: return 1e-3; case .micromolar: return 1e-6 } }
}
public enum VolumeUnit: String, ScaledUnit {
    case liter = "L", milliliter = "mL", microliter = "μL"
    public var scale: Double { switch self { case .liter: return 1; case .milliliter: return 1e-3; case .microliter: return 1e-6 } }
}
public enum MassUnit: String, ScaledUnit {
    case gram = "g", milligram = "mg", microgram = "μg"
    public var scale: Double { switch self { case .gram: return 1; case .milligram: return 1e-3; case .microgram: return 1e-6 } }
}
public enum DilutionVariable: String, CaseIterable, Identifiable {
    case c1, v1, c2, v2
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .c1: return "C1 · Stock concentration"
        case .v1: return "V1 · Stock volume"
        case .c2: return "C2 · Target concentration"
        case .v2: return "V2 · Final volume"
        }
    }
}
public struct DilutionResult {
    public let c1: Double, v1: Double, c2: Double, v2: Double
    public subscript(_ variable: DilutionVariable) -> Double {
        switch variable { case .c1: return c1; case .v1: return v1; case .c2: return c2; case .v2: return v2 }
    }
}
