import SwiftUI
import BioChemCore

struct DilutionToolsView: View {
    @State private var unknown: DilutionVariable = .v1
    @State private var values: [DilutionVariable: String] = [.c1: "10", .v1: "", .c2: "1", .v2: "100"]
    @State private var c1Unit: ConcentrationUnit = .millimolar
    @State private var c2Unit: ConcentrationUnit = .millimolar
    @State private var v1Unit: VolumeUnit = .milliliter
    @State private var v2Unit: VolumeUnit = .milliliter
    var body: some View {
        ToolPage(title: "Dilution Calculator", subtitle: "C1 × V1 = C2 × V2 · 选择一个未知量，输入其余三个量") {
            Picker("Calculate", selection: $unknown) { ForEach(DilutionVariable.allCases) { Text($0.title).tag($0) } }
            ForEach(DilutionVariable.allCases) { variable in
                HStack {
                    Text(variable.title).frame(width: 210, alignment: .leading)
                    if variable == unknown {
                        Text("由下方结果计算").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField("数值", text: Binding(get: { values[variable, default: ""] }, set: { values[variable] = $0 }))
                            .textFieldStyle(.roundedBorder).accessibilityLabel(variable.title)
                    }
                    switch variable {
                    case .c1: UnitPicker(selection: $c1Unit)
                    case .c2: UnitPicker(selection: $c2Unit)
                    case .v1: UnitPicker(selection: $v1Unit)
                    case .v2: UnitPicker(selection: $v2Unit)
                    }
                }
            }
            switch Result(catching: solve) {
            case .failure(let error): CalculationFailure(error: error)
            case .success(let r):
                ResultRow(label: "\(unknown.title)", value: display(r[unknown], variable: unknown))
                CopyButton(title: "Copy result", text: DilutionVariable.allCases.map { "\($0.title): \(display(r[$0], variable: $0))" }.joined(separator: "\n"))
            }
            Text("内部使用 M 与 L。各已知量必须大于 0；拒绝 C2 > C1 或 V1 > V2 的非稀释条件。V2 指最终总体积，应定容至 V2，而不是再加入 V2 的溶剂。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func solve() throws -> DilutionResult {
        var known: [DilutionVariable: Double] = [:]
        for variable in DilutionVariable.allCases where variable != unknown {
            let number = try UnitConverter.number(values[variable, default: ""], field: variable.title)
            switch variable {
            case .c1: known[variable] = try UnitConverter.convert(number, from: c1Unit, to: .molar)
            case .c2: known[variable] = try UnitConverter.convert(number, from: c2Unit, to: .molar)
            case .v1: known[variable] = try UnitConverter.convert(number, from: v1Unit, to: .liter)
            case .v2: known[variable] = try UnitConverter.convert(number, from: v2Unit, to: .liter)
            }
        }
        return try SolutionCalculator.dilution(solving: unknown, known: known)
    }
    private func display(_ value: Double, variable: DilutionVariable) -> String {
        switch variable {
        case .c1: return unitDisplay(value, from: ConcentrationUnit.molar, to: c1Unit)
        case .c2: return unitDisplay(value, from: ConcentrationUnit.molar, to: c2Unit)
        case .v1: return unitDisplay(value, from: VolumeUnit.liter, to: v1Unit)
        case .v2: return unitDisplay(value, from: VolumeUnit.liter, to: v2Unit)
        }
    }
}
struct MolarityToolsView: View {
    @State private var mw = ""
    @State private var concentration = ""
    @State private var volume = ""
    @State private var cUnit: ConcentrationUnit = .millimolar
    @State private var vUnit: VolumeUnit = .milliliter
    @State private var mUnit: MassUnit = .milligram
    var body: some View {
        ToolPage(title: "Molarity / Mass", subtitle: "Required mass · 按所填分子量和目标摩尔浓度计算") {
            HStack {
                Text("Molecular weight").frame(width: 170, alignment: .leading)
                TextField("例如 58.44", text: $mw).textFieldStyle(.roundedBorder).accessibilityLabel("Molecular weight")
                Text("g/mol").frame(width: 90)
            }
            HStack {
                Text("Target concentration").frame(width: 170, alignment: .leading)
                TextField("例如 100", text: $concentration).textFieldStyle(.roundedBorder).accessibilityLabel("Target concentration")
                UnitPicker(selection: $cUnit)
            }
            HStack {
                Text("Final volume").frame(width: 170, alignment: .leading)
                TextField("例如 10", text: $volume).textFieldStyle(.roundedBorder).accessibilityLabel("Final volume")
                UnitPicker(selection: $vUnit)
            }
            HStack { Text("Mass unit"); UnitPicker(selection: $mUnit) }
            switch Result(catching: { try SolutionCalculator.requiredMass(
                molecularWeight: UnitConverter.number(mw, field: "Molecular weight"),
                concentration: UnitConverter.number(concentration, field: "Target concentration"), concentrationUnit: cUnit,
                volume: UnitConverter.number(volume, field: "Final volume"), volumeUnit: vUnit, massUnit: mUnit) }) {
            case .failure(let error): CalculationFailure(error: error)
            case .success(let mass):
                ResultRow(label: "Required mass", value: "\(numeric(mass, digits: 6)) \(mUnit.rawValue)")
            }
            Text("内部以 mol/L、L、g 计算。请使用实际盐型或水合物的分子量；默认纯度 100%，未做纯度修正。最终体积为定容体积。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
private struct UnitPicker<U: ScaledUnit & Hashable>: View where U.AllCases: RandomAccessCollection {
    @Binding var selection: U
    var body: some View {
        Picker("单位", selection: $selection) { ForEach(U.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 90)
    }
}
private func unitDisplay<U: ScaledUnit>(_ value: Double, from: U, to: U) -> String {
    guard let number = try? UnitConverter.convert(value, from: from, to: to) else { return "换算结果不可表示" }
    return "\(numeric(number, digits: 6)) \(to.rawValue)"
}
