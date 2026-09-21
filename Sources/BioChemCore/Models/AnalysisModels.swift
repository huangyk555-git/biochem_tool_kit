import Foundation

public enum AnalysisError: LocalizedError, Equatable {
    case emptySequence, invalidCharacters(String), multipleFASTA, malformedFASTA, tooLong
    case invalidNumber(String), unsuitablePrimer, noChargeRoot
    public var errorDescription: String? {
        switch self {
        case .emptySequence: return "请输入序列。"
        case .invalidCharacters(let symbols): return "非法字符：\(symbols)。DNA 仅接受 A/T/G/C；蛋白质仅接受 20 种标准单字母氨基酸。"
        case .multipleFASTA: return "一次只分析一条 FASTA 序列，请勿合并多个记录。"
        case .malformedFASTA: return "FASTA header 必须位于序列之前，并以 > 开头。"
        case .tooLong: return "单次最多分析 100,000 个碱基或残基。"
        case .invalidNumber(let field): return "\(field)：请输入有效范围内的有限数值。"
        case .unsuitablePrimer: return "General primer 近似法要求每条引物至少 14 nt；短序列请选择 Wallace。"
        case .noChargeRoot: return "在 pH 0–14 中未找到净电荷为零的位置。"
        }
    }
}

public struct DNAResult {
    public let sequence: String
    public let counts: [Character: Int]
    public var length: Int { sequence.count }
    public var gcPercent: Double { 100 * Double(counts["G", default: 0] + counts["C", default: 0]) / Double(length) }
    public var atPercent: Double { 100 - gcPercent }
    public var reversed: String { String(sequence.reversed()) }
    /// Complement is aligned antiparallel (3′→5′) to the input (5′→3′).
    public var complement: String { String(sequence.map { SequenceUtilities.complementMap[$0]! }) }
    public var reverseComplement: String { String(complement.reversed()) }
}

public enum TmMethod: String, CaseIterable, Identifiable {
    case wallace, gcSaltAdjusted
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .wallace: return "Short oligo · Wallace"
        case .gcSaltAdjusted: return "General primer · GC / Na⁺"
        }
    }
}
public struct PrimerResult {
    public let dna: DNAResult
    public let molecularWeight: Double
    public let wallaceTm: Double
    public let generalTm: Double?
    public let sodiumMillimolar: Double
    public func tm(for method: TmMethod) throws -> Double {
        if method == .wallace { return wallaceTm }
        guard let generalTm else { throw AnalysisError.unsuitablePrimer }
        return generalTm
    }
}
public struct PrimerPairResult {
    public let forwardTm: Double
    public let reverseTm: Double
    public let method: TmMethod
    public var deltaTm: Double { abs(forwardTm - reverseTm) }
    /// Rule-of-thumb starting range only, not a thermodynamic PCR prediction.
    public var annealingRange: ClosedRange<Double> { (min(forwardTm, reverseTm) - 5)...(min(forwardTm, reverseTm) - 3) }
}
public struct TranslationResult {
    public let protein: String
    public let frame: Int
    public let trailingBases: Int
    public let stoppedAtCodon: Int?
}
public struct ResidueComposition: Identifiable {
    public let code: Character
    public let count: Int
    public let percent: Double
    public var id: String { String(code) }
}
public struct ProteinAnalysisResult {
    public let sequence: String
    public let molecularWeight: Double
    public let isoelectricPoint: Double
    public let composition: [ResidueComposition]
    public let counts: [Character: Int]
    public let averageResidueMass: Double
    public let extinctionReduced: Double
    public let extinctionMaxDisulfides: Double
    public var length: Int { sequence.count }
    public var acidicCount: Int { counts["D", default: 0] + counts["E", default: 0] }
    public var basicCount: Int { counts["K", default: 0] + counts["R", default: 0] + counts["H", default: 0] }
    public var aromaticCount: Int { counts["F", default: 0] + counts["W", default: 0] + counts["Y", default: 0] }
}
