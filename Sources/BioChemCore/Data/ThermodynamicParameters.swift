import Foundation

/// SantaLucia 1998, PNAS 95:1460, Table 2. ΔH kcal/mol, ΔS cal/(mol K).
/// A dinucleotide and its reverse complement describe the same antiparallel duplex step.
public enum ThermodynamicParameters {
    public static let steps: [String: (h: Double, s: Double)] = [
        "AA": (-7.9,-22.2), "TT": (-7.9,-22.2), "AT": (-7.2,-20.4), "TA": (-7.2,-21.3),
        "CA": (-8.5,-22.7), "TG": (-8.5,-22.7), "GT": (-8.4,-22.4), "AC": (-8.4,-22.4),
        "CT": (-7.8,-21.0), "AG": (-7.8,-21.0), "GA": (-8.2,-22.2), "TC": (-8.2,-22.2),
        "CG": (-10.6,-27.2), "GC": (-9.8,-24.4), "GG": (-8.0,-19.9), "CC": (-8.0,-19.9)
    ]
    public static let terminalAT = (h: 2.3, s: 4.1)
    public static let terminalGC = (h: 0.1, s: -2.8)
    public static let symmetryEntropy = -1.4
    public static let saltEntropyCoefficient = 0.368
    public static let gasConstant = 1.987
}
