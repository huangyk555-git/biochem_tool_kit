import SwiftUI
import BioChemCore

@MainActor final class ProteinWorkspace: ObservableObject {
    @Published var input = ""
    @Published var customDisulfidesText = "0"
    @Published var options = ProteinOptions()
}
struct ProteinOptionsView: View {
    @ObservedObject var model: ProteinWorkspace
    @State private var position = ""
    @State private var kind = ModificationKind.oxidation
    @State private var message: String?
    var body: some View {
        GroupBox("Protein Options / Modifications") {
            VStack(alignment:.leading,spacing:12) {
                Picker("N-terminal",selection:$model.options.nTerm) { ForEach(NTerminalOption.allCases) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("protein.nTermPicker")
                Toggle("C-terminal amidation (Native when off)",isOn:$model.options.amidated).accessibilityIdentifier("protein.amidation")
                Picker("Disulfides",selection:$model.options.disulfide) { ForEach(DisulfideOption.allCases) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("protein.disulfidePicker")
                if model.options.disulfide == .custom {
                    TextField("Custom disulfide count",text:$model.customDisulfidesText).textFieldStyle(.roundedBorder).accessibilityIdentifier("protein.disulfideCount")
                        .onChange(of:model.customDisulfidesText) { model.options.customDisulfides = Int($0) ?? -1 }
                }
                HStack {
                    Picker("Modification",selection:$kind) { ForEach(ModificationKind.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("1-based position",text:$position).textFieldStyle(.roundedBorder).frame(width:135).accessibilityIdentifier("protein.modPosition")
                    Button("Add") {
                        guard let index = Int(position) else { message = "位置必须为整数。"; return }
                        var candidate = model.options
                        candidate.modifications.append(ProteinModification(kind:kind,position:index))
                        do { _ = try ProteinModificationCalculator.calculate(model.input,options:candidate); model.options = candidate; message = nil }
                        catch { message = error.localizedDescription }
                    }.accessibilityIdentifier("protein.addModification")
                }
                Text("允许残基：\(kind.targetResidues)；位置按原始序列，从 1 开始。每个残基最多一个修饰。").font(.caption)
                ForEach(model.options.modifications) { modification in
                    HStack {
                        Text("\(modification.position): \(modification.kind.rawValue) +\(numeric(modification.kind.massShift, digits:4)) Da")
                        Spacer()
                        Button("Remove") { model.options.modifications.removeAll { $0.position == modification.position } }
                    }
                }
                if let message { Text(message).foregroundStyle(.orange) }
                Text("保留原始输入。pI/组成仍为原始无修饰序列；本轮不预测修饰后 pI。ε₂₈₀ 联动二硫键数，但仍假定 Trp/Tyr 的标准吸收，不模拟磷酸化等对吸收的变化。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(6)
        }.accessibilityIdentifier("protein.options")
    }
}
