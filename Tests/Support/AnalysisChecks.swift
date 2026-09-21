import Foundation
import BioChemCore

/// The same cases run under XCTest and the Command Line Tools-only regression runner.
public struct AnalysisCheck {
    public let name: String
    public let run: () throws -> Void
}
private struct CheckFailure: Error, CustomStringConvertible { let description: String }
private func expect(_ condition: Bool, _ message: String = "unexpected result") throws {
    if !condition { throw CheckFailure(description: message) }
}
private func near(_ actual: Double, _ expected: Double, tolerance: Double = 1e-8) throws {
    try expect(abs(actual - expected) <= tolerance, "expected \(expected), got \(actual)")
}
private func rejects(_ body: () throws -> Void) throws {
    do { try body() } catch is AnalysisError { return }
    throw CheckFailure(description: "expected AnalysisError")
}
public enum AnalysisChecks {
    public static let primer: [AnalysisCheck] = [
        .init(name: "primer normalization, length and GC/AT") {
            let r = try PrimerCalculator.analyze(" atgc\n atgc \t")
            try expect(r.dna.sequence == "ATGCATGC" && r.dna.length == 8)
            try near(r.dna.gcPercent, 50); try near(r.dna.atPercent, 50)
            try expect(r.dna.reverseComplement == "GCATGCAT")
        },
        .init(name: "Wallace and unmodified DNA mass") {
            let r = try PrimerCalculator.analyze("ATGCATGC")
            try near(r.wallaceTm, 24); try near(r.molecularWeight, 2409.64)
            try expect(r.generalTm == nil)
        },
        .init(name: "general Tm at 50 mM Na and salt dependence") {
            let s = "ATGCATGCATGCATGCATGC"
            let r = try PrimerCalculator.analyze(s)
            try near(r.generalTm!, 55.9779490507314)
            try expect(try PrimerCalculator.analyze(s, sodiumMillimolar: 100).generalTm! > r.generalTm!)
        },
        .init(name: "primer pair difference and annealing estimate") {
            let r = try PrimerCalculator.pair(forward: "ATGC", reverse: "GGCC", method: .wallace)
            try near(r.forwardTm, 12); try near(r.reverseTm, 16); try near(r.deltaTm, 4)
            try expect(r.annealingRange == 7...9)
        },
        .init(name: "short general primer and invalid salt rejected") {
            try rejects { _ = try PrimerCalculator.pair(forward: "ATGC", reverse: "GGCC") }
            for n in [0.0, -1, 1001, .nan, .infinity] {
                try rejects { _ = try PrimerCalculator.analyze("ATGC", sodiumMillimolar: n) }
            }
        },
        .init(name: "DNA invalid, ambiguous, Unicode and empty rejected") {
            for s in ["", " \n", "ATGN", "ATGU", "ATG1", "ＡTGC", "aß", ">header\nATGC"] {
                try rejects { _ = try SequenceUtilities.dna(s) }
            }
        }
    ]
    public static let protein: [AnalysisCheck] = [
        .init(name: "protein FASTA and whitespace normalization") {
            let r = try ProteinCalculator.analyze(">sample description\r\n a g\n")
            try expect(r.sequence == "AG" && r.length == 2)
            try near(r.molecularWeight, 146.1445)
            try near(r.averageResidueMass, 64.0646)
        },
        .init(name: "single residue retains one water and terminal pKa") {
            let r = try ProteinCalculator.analyze("A")
            try near(r.molecularWeight, 89.0932); try near(r.isoelectricPoint, 5.57)
        },
        .init(name: "Bjellqvist reference pI values") {
            try near(try ProteinCalculator.analyze("INGAR").isoelectricPoint, 9.75, tolerance: 0.01)
            try near(try ProteinCalculator.analyze("PETER").isoelectricPoint, 4.53, tolerance: 0.01)
        },
        .init(name: "pI stable and net charge root for acidic and basic proteins") {
            for s in ["DDD", "KKK", "INGAR", "PETER", "ACDEFGHIKLMNPQRSTVWY"] {
                let r = try ProteinCalculator.analyze(s)
                try expect((0...14).contains(r.isoelectricPoint))
                try near(try ProteinCalculator.netCharge(s, pH: r.isoelectricPoint), 0)
                try near(try ProteinCalculator.analyze(s).isoelectricPoint, r.isoelectricPoint)
                try expect(try ProteinCalculator.netCharge(s, pH: 2) > ProteinCalculator.netCharge(s, pH: 12))
            }
            try expect(try ProteinCalculator.analyze("DDD").isoelectricPoint < 4)
            try expect(try ProteinCalculator.analyze("KKK").isoelectricPoint > 9)
        },
        .init(name: "amino acid composition and residue classes") {
            let r = try ProteinCalculator.analyze("ACDEFGHIKLMNPQRSTVWY")
            try expect(r.length == 20 && r.composition.count == 20)
            try expect(r.composition.allSatisfy { $0.count == 1 && $0.percent == 5 })
            try expect(r.acidicCount == 2 && r.basicCount == 3 && r.aromaticCount == 3)
            try near(r.composition.reduce(0) { $0 + $1.percent }, 100)
        },
        .init(name: "Trp Tyr Cys and odd-cysteine extinction bounds") {
            let r = try ProteinCalculator.analyze("WCYCC")
            try expect(r.counts["W"] == 1 && r.counts["Y"] == 1 && r.counts["C"] == 3)
            try near(r.extinctionReduced, 6990); try near(r.extinctionMaxDisulfides, 7115)
        },
        .init(name: "invalid protein and multiple or misplaced FASTA rejected") {
            for s in ["", ">empty", "AXB", "AUO", "A*G", "A1", "ß", ">one\nAG\n>two\nCC", "AG\n>late\nCC"] {
                try rejects { _ = try ProteinCalculator.analyze(s) }
            }
            try rejects { _ = try ProteinCalculator.netCharge("AG", pH: .nan) }
        }
    ]
    public static let sequence: [AnalysisCheck] = [
        .init(name: "DNA reverse, complement and reverse complement") {
            let r = try SequenceUtilities.dna("ATGCC")
            try expect(r.reversed == "CCGTA" && r.complement == "TACGG" && r.reverseComplement == "GGCAT")
            try expect(try SequenceUtilities.dna(r.reverseComplement).reverseComplement == r.sequence)
        },
        .init(name: "GC extremes and input length limit") {
            try near(try SequenceUtilities.dna("GGCC").gcPercent, 100)
            try near(try SequenceUtilities.dna("ATTA").gcPercent, 0)
            try rejects { _ = try SequenceUtilities.dna(String(repeating: "A", count: 100_001)) }
            try rejects { _ = try SequenceUtilities.protein(String(repeating: "A", count: 100_001)) }
        },
        .init(name: "standard translation and stop behavior") {
            let s = "ATGGCTTAATTT"
            let stopped = try SequenceUtilities.translate(s)
            try expect(stopped.protein == "MA" && stopped.stoppedAtCodon == 3)
            let full = try SequenceUtilities.translate(s, stopAtStop: false)
            try expect(full.protein == "MA*F" && full.stoppedAtCodon == nil)
        },
        .init(name: "three reading frames and trailing bases") {
            let s = "AATGAAACC"
            let f1 = try SequenceUtilities.translate(s, frame: 1, stopAtStop: false)
            let f2 = try SequenceUtilities.translate(s, frame: 2, stopAtStop: false)
            let f3 = try SequenceUtilities.translate(s, frame: 3, stopAtStop: false)
            try expect(f1.protein == "NET" && f1.trailingBases == 0)
            try expect(f2.protein == "MK" && f2.trailingBases == 2)
            try expect(f3.protein == "*N" && f3.trailingBases == 1)
            try expect(try SequenceUtilities.translate("A", frame: 3).protein.isEmpty)
            try rejects { _ = try SequenceUtilities.translate(s, frame: 0) }
            try rejects { _ = try SequenceUtilities.translate(s, frame: 4) }
        },
        .init(name: "genetic code completeness and standard stop codons") {
            try expect(GeneticCode.standard.count == 64)
            let stops = Set(GeneticCode.standard.filter { $0.value == "*" }.keys)
            try expect(stops == Set(["TAA", "TAG", "TGA"]))
            try expect(try SequenceUtilities.translate("ATGTGGCGTAAGACCGGT", stopAtStop: false).protein == "MWRKTG")
        }
    ]
    public static let units: [AnalysisCheck] = [
        .init(name: "concentration mM and micromolar conversions") {
            try near(try UnitConverter.convert(1, from: ConcentrationUnit.millimolar, to: .micromolar), 1000)
            try near(try UnitConverter.convert(1, from: ConcentrationUnit.micromolar, to: .millimolar), 0.001)
            try near(try UnitConverter.convert(1, from: ConcentrationUnit.molar, to: .micromolar), 1e6)
        },
        .init(name: "volume mL and microliter conversions") {
            try near(try UnitConverter.convert(1, from: VolumeUnit.milliliter, to: .microliter), 1000)
            try near(try UnitConverter.convert(1, from: VolumeUnit.microliter, to: .milliliter), 0.001)
        },
        .init(name: "mass mg and microgram conversions") {
            try near(try UnitConverter.convert(1, from: MassUnit.milligram, to: .microgram), 1000)
            try near(try UnitConverter.convert(1, from: MassUnit.microgram, to: .milligram), 0.001)
        },
        .init(name: "invalid units and nonfinite numeric input rejected") {
            for n in [-1.0, .nan, .infinity] { try rejects { _ = try UnitConverter.convert(n, from: MassUnit.gram, to: .milligram) } }
            try rejects { _ = try UnitConverter.convert(Double.greatestFiniteMagnitude, from: MassUnit.gram, to: .microgram) }
            try rejects { _ = try UnitConverter.convert(Double.leastNonzeroMagnitude, from: MassUnit.microgram, to: .gram) }
            for s in ["", "nan", "inf", "1,5", "1e999"] { try rejects { _ = try UnitConverter.number(s, field: "test") } }
            try near(try UnitConverter.number(" 1e-3 ", field: "test"), 0.001)
        },
        .init(name: "dilution solves each of four unknowns") {
            let values: [DilutionVariable: Double] = [.c1: 0.01, .v1: 0.01, .c2: 0.001, .v2: 0.1]
            for variable in DilutionVariable.allCases {
                let result = try SolutionCalculator.dilution(solving: variable, known: values.filter { $0.key != variable })
                for (key, expected) in values { try near(result[key], expected) }
            }
        },
        .init(name: "dilution rejects zero, missing, extra and concentration increase") {
            for values: [DilutionVariable: Double] in [[:], [.c1: 0, .c2: 1, .v2: 1], [.c1: 1, .c2: 2, .v2: 1], [.c1: 1, .c2: 1, .v2: .infinity], [.c1: 1, .v1: 1, .c2: 1, .v2: 1]] {
                try rejects { _ = try SolutionCalculator.dilution(solving: .v1, known: values) }
            }
        },
        .init(name: "molarity mass result consistent across all units") {
            for cu in ConcentrationUnit.allCases {
                for vu in VolumeUnit.allCases {
                    for mu in MassUnit.allCases {
                        let c = try UnitConverter.convert(0.1, from: .molar, to: cu)
                        let v = try UnitConverter.convert(0.01, from: .liter, to: vu)
                        let mass = try SolutionCalculator.requiredMass(molecularWeight: 58.44, concentration: c, concentrationUnit: cu, volume: v, volumeUnit: vu, massUnit: mu)
                        try near(try UnitConverter.convert(mass, from: mu, to: .gram), 0.05844)
                    }
                }
            }
        },
        .init(name: "molarity validates mass, volume and concentration") {
            for (mw, c, v) in [(0.0, 1.0, 1.0), (1, -1, 1), (1, 1, 0), (Double.nan, 1, 1), (1, 1, Double.infinity)] {
                try rejects { _ = try SolutionCalculator.requiredMass(molecularWeight: mw, concentration: c, concentrationUnit: .molar, volume: v, volumeUnit: .liter, massUnit: .gram) }
            }
            try near(try SolutionCalculator.requiredMass(molecularWeight: 58.44, concentration: 0, concentrationUnit: .molar, volume: 1, volumeUnit: .liter, massUnit: .gram), 0)
        }
    ]
    public static var all: [AnalysisCheck] { primer + protein + sequence + units }
}
