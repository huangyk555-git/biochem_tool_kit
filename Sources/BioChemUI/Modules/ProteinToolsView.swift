import SwiftUI
import BioChemCore

struct ProteinToolsView: View {
    @State private var input = ""
    var body: some View {
        ToolPage(title: "Protein Sequence Analyzer", subtitle: "Theoretical value · 无修饰、线性、游离 N/C 端、还原态蛋白质") {
            SequenceInput(title: "Protein sequence / single-record FASTA", text: $input,
                hint: "移除一个 FASTA header，忽略空白并大写；仅 20 种标准氨基酸，B/J/O/U/X/Z、数字、- 和 * 均报错。", normalizeDNA: false)
            switch Result(catching: { try ProteinCalculator.analyze(input) }) {
            case .failure(let error): CalculationFailure(error: error)
            case .success(let r):
                GroupBox("Theoretical value") {
                    ResultRow(label: "Sequence length", value: "\(r.length) aa")
                    ResultRow(label: "Theoretical molecular weight", value: "\(numeric(r.molecularWeight)) Da")
                    ResultRow(label: "Theoretical pI · Bjellqvist", value: numeric(r.isoelectricPoint))
                    ResultRow(label: "Average residue mass (excludes terminal H₂O)", value: "\(numeric(r.averageResidueMass)) Da")
                    ResultRow(label: "Acidic D+E / Basic K+R+H / Aromatic F+W+Y", value: "\(r.acidicCount) / \(r.basicCount) / \(r.aromaticCount)")
                    ResultRow(label: "Trp / Tyr / Cys", value: "\(r.counts["W", default: 0]) / \(r.counts["Y", default: 0]) / \(r.counts["C", default: 0])")
                }
                GroupBox("Estimated ε₂₈₀ · M⁻¹ cm⁻¹") {
                    ResultRow(label: "All cysteines reduced", value: numeric(r.extinctionReduced, digits: 0))
                    ResultRow(label: "Maximum paired disulfides", value: numeric(r.extinctionMaxDisulfides, digits: 0))
                    Text("第二项假定最多 floor(Cys/2) 对二硫键；不预测真实配对，也不改变上方还原态 MW / pI。缺少 Trp 时估计可能更不可靠。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack { CopyButton(title: "Copy sequence", text: r.sequence); CopyButton(title: "Copy result", text: report(r)) }
                SequenceOutput(title: "Normalized sequence", sequence: r.sequence)
                Text("Amino-acid composition").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], alignment: .leading, spacing: 10) {
                    ForEach(r.composition) { aa in
                        HStack {
                            Text(String(aa.code)).bold()
                            Spacer()
                            Text("\(aa.count) · \(numeric(aa.percent, digits: 1))%").monospacedDigit()
                        }.padding(9).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Text("MW = Σ残基质量 + 1 H₂O（等价于游离氨基酸总质量减去 n−1 个 H₂O）。pI 使用 Bjellqvist pKa，计入 N/C 端及 D/E/C/Y/H/K/R 侧链，在 pH 0–14 二分求净电荷零点；未考虑修饰、信号肽切除、聚集、二硫键对 pI 的影响或局部微环境。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func report(_ r: ProteinAnalysisResult) -> String {
        let composition = r.composition.map { "\($0.code)\t\($0.count)\t\(numeric($0.percent))%" }.joined(separator: "\n")
        return "Theoretical value (unmodified linear reduced protein)\nSequence: \(r.sequence)\nLength: \(r.length) aa\nMW: \(numeric(r.molecularWeight)) Da\npI (Bjellqvist): \(numeric(r.isoelectricPoint))\nAverage residue mass (without terminal water): \(numeric(r.averageResidueMass)) Da\nAcidic D+E: \(r.acidicCount)\nBasic K+R+H: \(r.basicCount)\nAromatic F+W+Y: \(r.aromaticCount)\nTrp/Tyr/Cys: \(r.counts["W", default: 0])/\(r.counts["Y", default: 0])/\(r.counts["C", default: 0])\nEstimated epsilon280 (reduced / max disulfides): \(numeric(r.extinctionReduced)) / \(numeric(r.extinctionMaxDisulfides)) M^-1 cm^-1\nComposition (count, percent):\n\(composition)"
    }
}
