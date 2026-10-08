import Foundation
public enum ProteinPICalculator {
    public static func calculate(_ input: String) throws -> Double {
        let sequence = try SequenceUtilities.protein(input)
        guard let first = sequence.first, let last = sequence.last else { throw AnalysisError.emptySequence }
        let counts = sequence.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        var low = 0.0, high = 14.0
        guard chargeAt(low, counts: counts, first: first, last: last) >= 0,
              chargeAt(high, counts: counts, first: first, last: last) <= 0 else { throw AnalysisError.noChargeRoot }
        for _ in 0..<60 {
            let mid = (low+high)/2
            if chargeAt(mid, counts: counts, first: first, last: last) > 0 { low = mid } else { high = mid }
        }
        return (low+high)/2
    }
    public static func netCharge(_ input: String, pH: Double) throws -> Double {
        guard pH.isFinite, (0...14).contains(pH) else { throw AnalysisError.invalidNumber("pH（0–14）") }
        let sequence = try SequenceUtilities.protein(input)
        let counts = sequence.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        guard let first = sequence.first, let last = sequence.last else { throw AnalysisError.emptySequence }
        return chargeAt(pH, counts: counts, first: first, last: last)
    }
    private static func chargeAt(_ pH: Double, counts: [Character: Int], first: Character, last: Character) -> Double {
        func positive(_ pKa: Double) -> Double { 1 / (1 + pow(10, pH - pKa)) }
        func negative(_ pKa: Double) -> Double { 1 / (1 + pow(10, pKa - pH)) }
        var charge = positive(ProteinConstants.nTermOverrides[first] ?? ProteinConstants.nTermPKa)
            - negative(ProteinConstants.cTermOverrides[last] ?? ProteinConstants.cTermPKa)
        for (aa, pKa) in ProteinConstants.basicPKa { charge += Double(counts[aa, default: 0]) * positive(pKa) }
        for (aa, pKa) in ProteinConstants.acidicPKa { charge -= Double(counts[aa, default: 0]) * negative(pKa) }
        return charge
    }
}
