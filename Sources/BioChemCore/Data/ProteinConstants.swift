import Foundation

/// Average isotopic masses, g/mol. Factual constants cross-checked against
/// Biopython Bio.Data.IUPACData; methods and references: docs/CALCULATIONS.md.
public enum ProteinConstants {
    public static let waterMass = 18.0153
    public static let freeAminoAcidMasses: [Character: Double] = [
        "A": 89.0932, "C": 121.1582, "D": 133.1027, "E": 147.1293,
        "F": 165.1891, "G": 75.0666, "H": 155.1546, "I": 131.1729,
        "K": 146.1876, "L": 131.1729, "M": 149.2113, "N": 132.1179,
        "P": 115.1305, "Q": 146.1445, "R": 174.2010, "S": 105.0926,
        "T": 119.1192, "V": 117.1463, "W": 204.2252, "Y": 181.1885
    ]
    public static let residueMasses = freeAminoAcidMasses.mapValues { $0 - waterMass }
    // Bjellqvist peptide pKa set including sequence-specific terminal corrections.
    public static let basicPKa: [Character: Double] = ["K": 10.0, "R": 12.0, "H": 5.98]
    public static let acidicPKa: [Character: Double] = ["D": 4.05, "E": 4.45, "C": 9.0, "Y": 10.0]
    public static let nTermPKa = 7.5
    public static let cTermPKa = 3.55
    public static let nTermOverrides: [Character: Double] = ["A": 7.59, "M": 7.0, "S": 6.93, "P": 8.36, "T": 6.82, "V": 7.44, "E": 7.7]
    public static let cTermOverrides: [Character: Double] = ["D": 4.55, "E": 4.75]
}
