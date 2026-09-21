import Foundation

/// Base units: mol/L, L, g. No unit conversion arithmetic is needed in the views.
public enum UnitConverter {
    public static func convert<U: ScaledUnit>(_ value: Double, from: U, to: U) throws -> Double {
        guard value.isFinite, value >= 0 else { throw AnalysisError.invalidNumber("单位换算") }
        let result = value * (from.scale / to.scale)
        guard result.isFinite, value == 0 || result > 0 else { throw AnalysisError.invalidNumber("换算结果溢出或下溢") }
        return result
    }
    public static func number(_ input: String, field: String) throws -> Double {
        guard let result = Double(input.trimmingCharacters(in: .whitespacesAndNewlines)), result.isFinite else {
            throw AnalysisError.invalidNumber(field + "（小数点使用 .，可用科学计数法）")
        }
        return result
    }
}
