import Foundation

public enum ToolError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
public enum PrimerTmMethod: String, CaseIterable, Identifiable {
    case auto = "Auto", wallace = "Wallace", basic = "Basic", nearestNeighbor = "Nearest Neighbor"
    public var id: String { rawValue }
}
public struct TmEstimate {
    public let value: Double
    public let method: PrimerTmMethod
    public let thermodynamics: NearestNeighborResult?
}
public enum PrimerTmCalculator {
    public static func wallace(_ dna: DNAResult) -> Double {
        Double(2 * (dna.counts["A",default:0] + dna.counts["T",default:0]) + 4 * (dna.counts["G",default:0] + dna.counts["C",default:0]))
    }
    public static func basic(_ dna: DNAResult, saltMillimolar: Double) throws -> Double {
        guard dna.length >= 14 else { throw AnalysisError.unsuitablePrimer }
        guard saltMillimolar.isFinite, (1...1000).contains(saltMillimolar) else { throw ToolError.invalid("单价盐必须为 1–1000 mM。") }
        return 77.1 + 0.41 * dna.gcPercent - 528 / Double(dna.length) + 11.7 * log10(saltMillimolar / 1000)
    }
    public static func calculate(_ sequence: String, method: PrimerTmMethod = .auto,
                                 primerNanomolar: Double = 250, saltMillimolar: Double = 50) throws -> TmEstimate {
        let dna = try SequenceUtilities.dna(sequence)
        let resolved = method == .auto ? (dna.length < 14 ? PrimerTmMethod.wallace : .nearestNeighbor) : method
        switch resolved {
        case .wallace: return TmEstimate(value: wallace(dna), method: resolved, thermodynamics: nil)
        case .basic: return TmEstimate(value: try basic(dna, saltMillimolar: saltMillimolar), method: resolved, thermodynamics: nil)
        case .nearestNeighbor:
            let nn = try NearestNeighborTmCalculator.calculate(sequence, primerNanomolar: primerNanomolar, saltMillimolar: saltMillimolar)
            return TmEstimate(value: nn.tm, method: resolved, thermodynamics: nn)
        case .auto: throw ToolError.invalid("无法选择 Tm 方法。")
        }
    }
}
