import Foundation

/// Average masses from Unimod (not monoisotopic). This UI intentionally supports a subset of sites.
public enum ModificationKind: String, CaseIterable, Identifiable {
    case phosphorylation = "Phosphorylation", oxidation = "Oxidation", methylation = "Methylation", acetylation = "Acetylation"
    public var id: String { rawValue }
    public var massShift: Double { switch self { case .phosphorylation: return 79.9799; case .oxidation: return 15.9994; case .methylation: return 14.0266; case .acetylation: return 42.0367 } }
    public var targetResidues: String { switch self { case .phosphorylation: return "STY"; case .oxidation: return "M"; case .methylation: return "KR"; case .acetylation: return "K" } }
}
public struct ProteinModification: Identifiable {
    public let kind: ModificationKind
    /// 1-based ORIGINAL sequence position, before any N-terminal removal.
    public let position: Int
    public var id: Int { position }
    public init(kind: ModificationKind, position: Int) { self.kind = kind; self.position = position }
}
public enum NTerminalOption: String, CaseIterable, Identifiable {
    case native = "Native", removeMet = "N-terminal Met removed", acetylated = "Acetylation"
    public var id: String { rawValue }
}
public enum DisulfideOption: String, CaseIterable, Identifiable {
    case reduced = "Reduced", custom = "Custom disulfides", maximum = "Maximum possible disulfides"
    public var id: String { rawValue }
}
public struct ProteinOptions {
    public var nTerm: NTerminalOption = .native
    public var amidated = false
    public var disulfide: DisulfideOption = .reduced
    public var customDisulfides = 0
    public var modifications: [ProteinModification] = []
    public init() {}
}
public struct ModifiedProteinResult {
    public let baseMW: Double
    public let deltaMass: Double
    public let finalMW: Double
    public let disulfides: Int
    public let extinction: Double
    public let effectiveSequence: String
}
