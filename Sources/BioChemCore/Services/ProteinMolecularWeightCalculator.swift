import Foundation
public enum ProteinMolecularWeightCalculator {
    public static func calculate(_ input: String) throws -> Double {
        let sequence = try SequenceUtilities.protein(input)
        return try sequence.reduce(ProteinConstants.waterMass) { mass, residue in
            guard let value = ProteinConstants.residueMasses[residue] else { throw AnalysisError.invalidCharacters(String(residue)) }
            return mass + value
        }
    }
}
