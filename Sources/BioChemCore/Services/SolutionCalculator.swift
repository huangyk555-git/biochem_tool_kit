import Foundation

public enum SolutionCalculator {
    /// Supply exactly the three known values, in M and L.
    public static func dilution(solving unknown: DilutionVariable, known: [DilutionVariable: Double]) throws -> DilutionResult {
        guard known.count == 3, known[unknown] == nil,
              known.values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw AnalysisError.invalidNumber("稀释计算的三个已知量（必须 > 0）")
        }
        var values = known
        switch unknown {
        case .c1: values[.c1] = known[.c2]! * (known[.v2]! / known[.v1]!)
        case .v1: values[.v1] = (known[.c2]! / known[.c1]!) * known[.v2]!
        case .c2: values[.c2] = known[.c1]! * (known[.v1]! / known[.v2]!)
        case .v2: values[.v2] = (known[.c1]! / known[.c2]!) * known[.v1]!
        }
        guard values.values.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw AnalysisError.invalidNumber("稀释结果溢出或下溢") }
        let result = DilutionResult(c1: values[.c1]!, v1: values[.v1]!, c2: values[.c2]!, v2: values[.v2]!)
        guard result.c2 / result.c1 <= 1 + 1e-12, result.v1 / result.v2 <= 1 + 1e-12 else {
            throw AnalysisError.invalidNumber("稀释要求 C2 ≤ C1 且 V1 ≤ V2")
        }
        return result
    }
    public static func requiredMass(molecularWeight: Double, concentration: Double, concentrationUnit: ConcentrationUnit,
                                    volume: Double, volumeUnit: VolumeUnit, massUnit: MassUnit) throws -> Double {
        guard molecularWeight.isFinite, molecularWeight > 0, volume.isFinite, volume > 0,
              concentration.isFinite, concentration >= 0 else { throw AnalysisError.invalidNumber("分子量 / 浓度 / 体积") }
        let molarity = try UnitConverter.convert(concentration, from: concentrationUnit, to: .molar)
        let liters = try UnitConverter.convert(volume, from: volumeUnit, to: .liter)
        let grams = molecularWeight * molarity * liters
        guard grams.isFinite, concentration == 0 || grams > 0 else { throw AnalysisError.invalidNumber("质量结果溢出或下溢") }
        return try UnitConverter.convert(grams, from: .gram, to: massUnit)
    }
}
