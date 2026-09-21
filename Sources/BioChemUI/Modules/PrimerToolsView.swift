import SwiftUI
import BioChemCore

struct PrimerToolsView: View {
    @State private var input = ""
    @State private var reverse = ""
    @State private var sodium = "50"
    @State private var method: TmMethod = .gcSaltAdjusted
    private var result: Result<PrimerResult, Error> {
        Result { try PrimerCalculator.analyze(input, sodiumMillimolar: UnitConverter.number(sodium, field: "Na⁺")) }
    }
    var body: some View {
        ToolPage(title: "Primer / Oligo Tools", subtitle: "Estimated values · 无修饰单链 DNA，5′-OH / 3′-OH") {
            SequenceInput(title: "DNA primer sequence · 5′ → 3′", text: $input, hint: "仅允许 A/T/G/C。自动去空白并大写；非法字符保留并提示。")
            HStack {
                Text("Na⁺ (mM)")
                TextField("50", text: $sodium).frame(width: 90).textFieldStyle(.roundedBorder).accessibilityLabel("Na concentration mM")
                Text("仅 General primer 使用，1–1000 mM").font(.caption).foregroundStyle(.secondary)
            }
            switch result {
            case .failure(let error): CalculationFailure(error: error)
            case .success(let r):
                GroupBox("Oligo summary") {
                    ResultRow(label: "Sequence length", value: "\(r.dna.length) nt")
                    ResultRow(label: "GC / AT content", value: "\(numeric(r.dna.gcPercent))% / \(numeric(r.dna.atPercent))%")
                    ResultRow(label: "Estimated molecular weight", value: "\(numeric(r.molecularWeight)) g/mol")
                    ResultRow(label: "Estimated Tm · Wallace", value: "\(numeric(r.wallaceTm)) °C")
                    ResultRow(label: "Estimated Tm · GC / Na⁺", value: r.generalTm.map { "\(numeric($0)) °C" } ?? "至少需要 14 nt")
                }
                HStack {
                    CopyButton(title: "Copy sequence", text: r.dna.sequence)
                    CopyButton(title: "Copy reverse complement", text: r.dna.reverseComplement)
                    CopyButton(title: "Copy result", text: report(r))
                }
                SequenceOutput(title: "Normalized sequence · 5′ → 3′", sequence: r.dna.sequence)
                SequenceOutput(title: "Reverse complement · 5′ → 3′", sequence: r.dna.reverseComplement)
            }
            Text("Calculation methods: Wallace = 2(A+T)+4(G+C)，仅为短寡核苷酸粗略估计；General = von Ahsen GC/Na⁺ 经验式。未计入 Mg²⁺、dNTP、引物浓度、错配、发卡或二聚体，不是 nearest-neighbor 预测。")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Primer pair · Estimated annealing range").font(.title3.bold())
            Text("上方序列作为 Forward primer；下方输入 Reverse primer（均按 5′ → 3′）。").font(.caption)
            SequenceInput(title: "Reverse primer · 5′ → 3′", text: $reverse)
            Picker("Calculation method", selection: $method) { ForEach(TmMethod.allCases) { Text($0.title).tag($0) } }
            if !reverse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pairResults
            }
            Text("建议范围仅为较低 Tm 减 5 至减 3 °C 的经验起点；ΔTm > 5 °C 时建议重新评估引物配对。需结合聚合酶说明、缓冲体系及梯度 PCR 验证，不能作为严格 PCR 条件预测。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var pairResults: some View {
        let pair = Result { try PrimerCalculator.pair(forward: input, reverse: reverse, method: method,
            sodiumMillimolar: UnitConverter.number(sodium, field: "Na⁺")) }
        switch pair {
        case .failure(let error): CalculationFailure(error: error)
        case .success(let r):
            ResultRow(label: "Forward Tm / Reverse Tm", value: "\(numeric(r.forwardTm)) / \(numeric(r.reverseTm)) °C")
            ResultRow(label: "ΔTm", value: "\(numeric(r.deltaTm)) °C")
            ResultRow(label: "Annealing range · Estimate", value: "\(numeric(r.annealingRange.lowerBound))–\(numeric(r.annealingRange.upperBound)) °C")
            if r.deltaTm > 5 { Text("两条引物 Tm 差异较大；请重新评估配对。").foregroundStyle(.orange) }
        }
    }
    private func report(_ r: PrimerResult) -> String {
        "Sequence (5′→3′): \(r.dna.sequence)\nLength: \(r.dna.length) nt\nGC: \(numeric(r.dna.gcPercent))%\nAT: \(numeric(r.dna.atPercent))%\nEstimated MW: \(numeric(r.molecularWeight)) g/mol (ssDNA, 5′/3′ OH)\nReverse complement (5′→3′): \(r.dna.reverseComplement)\nEstimated Tm (Wallace): \(numeric(r.wallaceTm)) °C\nEstimated Tm (von Ahsen GC/Na⁺, Na⁺ \(numeric(r.sodiumMillimolar)) mM): \(r.generalTm.map { numeric($0) + " °C" } ?? "not applicable (<14 nt)")"
    }
}
