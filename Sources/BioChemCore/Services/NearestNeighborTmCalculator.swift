import Foundation

public struct NearestNeighborResult {
    public let tm: Double
    public let deltaH: Double
    /// Includes initiation, terminal and symmetry terms, before salt correction.
    public let deltaS: Double
    public let saltEntropy: Double
    public let selfComplementary: Bool
}
public enum NearestNeighborTmCalculator {
    /// Concentration is that of EACH strand for an equimolar non-self-complementary duplex;
    /// for a self-complementary oligo, it is the total concentration of that one strand species.
    public static func calculate(_ input: String, primerNanomolar: Double = 250, saltMillimolar: Double = 50) throws -> NearestNeighborResult {
        let dna = try SequenceUtilities.dna(input)
        guard (2...200).contains(dna.length) else { throw ToolError.invalid("Nearest Neighbor 支持 2–200 nt；极短序列仍仅作理论估计。") }
        guard primerNanomolar.isFinite, (0.01...1_000_000).contains(primerNanomolar),
              saltMillimolar.isFinite, (1...1000).contains(saltMillimolar) else {
            throw ToolError.invalid("浓度范围：primer 0.01–1,000,000 nM；单价盐 1–1000 mM。")
        }
        let bases = Array(dna.sequence)
        var h = 0.0, s = 0.0
        for index in 0..<(bases.count - 1) {
            guard let step = ThermodynamicParameters.steps[String(bases[index...index+1])] else { throw ToolError.invalid("缺少 NN 参数。") }
            h += step.h; s += step.s
        }
        for base in [bases[0], bases[bases.count-1]] {
            let terminal = (base == "A" || base == "T") ? ThermodynamicParameters.terminalAT : ThermodynamicParameters.terminalGC
            h += terminal.h; s += terminal.s
        }
        let symmetric = dna.sequence == dna.reverseComplement
        if symmetric { s += ThermodynamicParameters.symmetryEntropy }
        let salt = ThermodynamicParameters.saltEntropyCoefficient * Double(dna.length - 1) * log(saltMillimolar / 1000)
        let effectiveConcentration = primerNanomolar * 1e-9 / (symmetric ? 1 : 2)
        let tm = h * 1000 / (s + salt + ThermodynamicParameters.gasConstant * log(effectiveConcentration)) - 273.15
        guard tm.isFinite else { throw ToolError.invalid("Tm 不可表示。") }
        return NearestNeighborResult(tm: tm, deltaH: h, deltaS: s, saltEntropy: salt, selfComplementary: symmetric)
    }
}
