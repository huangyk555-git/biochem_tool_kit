import Foundation

public enum PrimerCalculator {
    // Average DNA nucleotide residue masses; unmodified ssDNA, 5′-OH / 3′-OH.
    // Supplier reference and method assumptions are recorded in docs/CALCULATIONS.md.
    public static let nucleotideMasses: [Character: Double] = ["A": 313.21, "T": 304.20, "G": 329.21, "C": 289.18]
    public static func analyze(_ input: String, sodiumMillimolar: Double = 50) throws -> PrimerResult {
        guard sodiumMillimolar.isFinite, (1...1000).contains(sodiumMillimolar) else {
            throw AnalysisError.invalidNumber("Na⁺ 浓度（1–1000 mM）")
        }
        let dna = try SequenceUtilities.dna(input)
        let wallace = PrimerTmCalculator.wallace(dna)
        let general = dna.length >= 14 ? try PrimerTmCalculator.basic(dna, saltMillimolar: sodiumMillimolar) : nil
        let mass = dna.counts.reduce(0.0) { $0 + Double($1.value) * nucleotideMasses[$1.key, default: 0] } - 61.96
        return PrimerResult(dna: dna, molecularWeight: mass, wallaceTm: wallace, generalTm: general, sodiumMillimolar: sodiumMillimolar)
    }
    public static func pair(forward: String, reverse: String, method: TmMethod = .gcSaltAdjusted,
                            sodiumMillimolar: Double = 50) throws -> PrimerPairResult {
        let f = try analyze(forward, sodiumMillimolar: sodiumMillimolar).tm(for: method)
        let r = try analyze(reverse, sodiumMillimolar: sodiumMillimolar).tm(for: method)
        return PrimerPairResult(forwardTm: f, reverseTm: r, method: method)
    }
}
