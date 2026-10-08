import Foundation
import BioChemCore

public enum ScientificAudit {
    public static func report() throws -> [String:Any] {
        let sequences = [TestFixtures.publishedPrimer,"ATGCATGCATGCATGCATGC","GCGCGCGC","ATATATAT"]
        var dna: [[String:Any]] = []
        for sequence in sequences {
            for concentration in [25.0,250.0] {
                for salt in [50.0,100.0] {
                    let value = try NearestNeighborTmCalculator.calculate(sequence,primerNanomolar:concentration,saltMillimolar:salt)
                    var row: [String:Any] = ["sequence":sequence,"concentration":concentration,"salt":salt,"nn":value.tm,"selfComplementary":value.selfComplementary,"wallace":try PrimerTmCalculator.calculate(sequence,method:.wallace).value]
                    if sequence.count >= 14 { row["basic"] = try PrimerTmCalculator.calculate(sequence,method:.basic,saltMillimolar:salt).value }
                    dna.append(row)
                }
            }
        }
        let proteins = try ["AG","INGAR","PETER","ACDEFGHIKLMNPQRSTVWY","WYWCCCCC"].map { sequence -> [String:Any] in
            let result = try ProteinCalculator.analyze(sequence)
            return ["sequence":sequence,"mw":result.molecularWeight,"pi":result.isoelectricPoint,"reduced":result.extinctionReduced,"oxidized":result.extinctionMaxDisulfides]
        }
        return ["dna":dna,"proteins":proteins]
    }
}
