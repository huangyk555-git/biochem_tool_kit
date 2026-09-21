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
        let gc = dna.counts["G", default: 0] + dna.counts["C", default: 0]
        let wallace = Double(2 * (dna.length - gc) + 4 * gc)
        // von Ahsen et al. 2001 empirical GC formula (Biopython Tm_GC valueset 8).
        let general = dna.length >= 14 ? 77.1 + 0.41 * dna.gcPercent - 528 / Double(dna.length)
            + 11.7 * log10(sodiumMillimolar / 1000) : nil
        let mass = dna.counts.reduce(0.0) { $0 + Double($1.value) * nucleotideMasses[$1.key]! } - 61.96
        return PrimerResult(dna: dna, molecularWeight: mass, wallaceTm: wallace, generalTm: general, sodiumMillimolar: sodiumMillimolar)
    }
    public static func pair(forward: String, reverse: String, method: TmMethod = .gcSaltAdjusted,
                            sodiumMillimolar: Double = 50) throws -> PrimerPairResult {
        let f = try analyze(forward, sodiumMillimolar: sodiumMillimolar).tm(for: method)
        let r = try analyze(reverse, sodiumMillimolar: sodiumMillimolar).tm(for: method)
        return PrimerPairResult(forwardTm: f, reverseTm: r, method: method)
    }
}
