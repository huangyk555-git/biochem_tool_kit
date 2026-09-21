import Foundation

public enum ProteinCalculator {
    public static func analyze(_ input: String) throws -> ProteinAnalysisResult {
        let sequence = try SequenceUtilities.protein(input)
        let counts = sequence.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        let residueMass = counts.reduce(0.0) { $0 + Double($1.value) * ProteinConstants.residueMasses[$1.key]! }
        let charge: (Double) -> Double = { chargeAt($0, counts: counts, first: sequence.first!, last: sequence.last!) }
        var low = 0.0, high = 14.0
        guard charge(low) >= 0, charge(high) <= 0 else { throw AnalysisError.noChargeRoot }
        for _ in 0..<60 {
            let mid = (low + high) / 2
            if charge(mid) > 0 { low = mid } else { high = mid }
        }
        let reduced = Double(5500 * counts["W", default: 0] + 1490 * counts["Y", default: 0])
        let composition = ProteinConstants.residueMasses.keys.sorted().map {
            ResidueComposition(code: $0, count: counts[$0, default: 0], percent: 100 * Double(counts[$0, default: 0]) / Double(sequence.count))
        }
        return ProteinAnalysisResult(sequence: sequence, molecularWeight: residueMass + ProteinConstants.waterMass,
            isoelectricPoint: (low + high) / 2, composition: composition, counts: counts,
            averageResidueMass: residueMass / Double(sequence.count), extinctionReduced: reduced,
            extinctionMaxDisulfides: reduced + 125 * Double(counts["C", default: 0] / 2))
    }
    public static func netCharge(_ input: String, pH: Double) throws -> Double {
        guard pH.isFinite, (0...14).contains(pH) else { throw AnalysisError.invalidNumber("pH（0–14）") }
        let sequence = try SequenceUtilities.protein(input)
        let counts = sequence.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        return chargeAt(pH, counts: counts, first: sequence.first!, last: sequence.last!)
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
