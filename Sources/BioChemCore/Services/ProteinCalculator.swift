import Foundation

public enum ProteinCalculator {
    public static func analyze(_ input: String) throws -> ProteinAnalysisResult {
        let sequence = try SequenceUtilities.protein(input)
        let counts = sequence.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
        let residueMass = counts.reduce(0.0) { $0 + Double($1.value) * ProteinConstants.residueMasses[$1.key, default: 0] }
        let reduced = Double(5500 * counts["W", default: 0] + 1490 * counts["Y", default: 0])
        let composition = ProteinConstants.residueMasses.keys.sorted().map {
            ResidueComposition(code: $0, count: counts[$0, default: 0], percent: 100 * Double(counts[$0, default: 0]) / Double(sequence.count))
        }
        return ProteinAnalysisResult(sequence: sequence, molecularWeight: try ProteinMolecularWeightCalculator.calculate(sequence),
            isoelectricPoint: try ProteinPICalculator.calculate(sequence), composition: composition, counts: counts,
            averageResidueMass: residueMass / Double(sequence.count), extinctionReduced: reduced,
            extinctionMaxDisulfides: reduced + 125 * Double(counts["C", default: 0] / 2))
    }
    public static func netCharge(_ input: String, pH: Double) throws -> Double {
        try ProteinPICalculator.netCharge(input, pH: pH)
    }
}
