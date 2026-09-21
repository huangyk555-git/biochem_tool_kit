import SwiftUI
import BioChemCore

struct SequenceToolsView: View {
    let translation: Bool
    @State private var input = ""
    @State private var frame = 1
    @State private var stopAtStop = true
    var body: some View {
        ToolPage(title: translation ? "Translation" : "DNA Tools", subtitle: translation ? "Standard genetic code · NCBI table 1" : "DNA sequence inspection · 仅接受 A/T/G/C") {
            SequenceInput(title: "DNA sequence · 5′ → 3′", text: $input)
            if translation {
                HStack {
                    Picker("Reading frame", selection: $frame) { ForEach(1...3, id: \.self) { Text("+\($0)").tag($0) } }.frame(width: 200)
                    Toggle("Stop at first stop codon", isOn: $stopAtStop)
                }
                translationResults
                Text("翻译从所选 reading frame 开始，不查找起始 ATG；终止模式不输出 stop 的 *，继续模式以 * 标记 stop。末尾不足 3 个碱基不翻译。不进行 ORF 预测。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                dnaResults
            }
        }
    }
    @ViewBuilder private var dnaResults: some View {
        switch Result(catching: { try SequenceUtilities.dna(input) }) {
        case .failure(let error): CalculationFailure(error: error)
        case .success(let r):
            ResultRow(label: "Sequence length", value: "\(r.length) nt")
            ResultRow(label: "GC content", value: "\(numeric(r.gcPercent))%")
            SequenceOutput(title: "Normalized sequence · 5′ → 3′", sequence: r.sequence)
            SequenceOutput(title: "Reverse · 仅字符顺序反转", sequence: r.reversed)
            SequenceOutput(title: "Complement · 与输入对齐，3′ → 5′", sequence: r.complement)
            SequenceOutput(title: "Reverse complement · 5′ → 3′", sequence: r.reverseComplement)
        }
    }
    @ViewBuilder private var translationResults: some View {
        switch Result(catching: { try SequenceUtilities.translate(input, frame: frame, stopAtStop: stopAtStop) }) {
        case .failure(let error): CalculationFailure(error: error)
        case .success(let r):
            SequenceOutput(title: "Translated sequence · N → C", sequence: r.protein)
            ResultRow(label: "Output symbols (including * if retained)", value: "\(r.protein.count)")
            ResultRow(label: "Incomplete trailing bases (selected frame)", value: "\(r.trailingBases)")
            if let stop = r.stoppedAtCodon { Text("已在当前阅读框的第 \(stop) 个密码子停止。").font(.caption) }
        }
    }
}
