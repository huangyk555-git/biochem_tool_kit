import SwiftUI
import BioChemCore

struct ProteinToolsView: View {
    @ObservedObject var model: ProteinWorkspace
    var optionsFirst = false
    var body: some View {
        ToolPage(title: "Protein Sequence Analyzer", subtitle: "Theoretical values · Base = native / reduced；修饰结果单独列出") {
            SequenceInput(title: "Protein sequence / single-record FASTA", text: $model.input,
                hint: "移除一个 FASTA header，忽略空白并大写；仅 20 种标准氨基酸，B/J/O/U/X/Z、数字、- 和 * 均报错。", normalizeDNA: false, identifier: "protein.sequenceInput")
            if optionsFirst { ProteinOptionsView(model:model) }
            switch Result(catching: { try ProteinCalculator.analyze(model.input) }) {
            case .failure(let error): CalculationFailure(error: error)
            case .success(let r):
                GroupBox("Theoretical value") {
                    ResultRow(label: "Sequence length", value: "\(r.length) aa")
                    ResultRow(label: "Base theoretical molecular weight", value: "\(numeric(r.molecularWeight)) Da / \(numeric(r.molecularWeight/1000, digits:4)) kDa", identifier:"protein.baseMW")
                    ResultRow(label: "Base theoretical pI · Bjellqvist", value: numeric(r.isoelectricPoint), identifier:"protein.piResult")
                    ResultRow(label: "Average residue mass (excludes terminal H₂O)", value: "\(numeric(r.averageResidueMass)) Da")
                    ResultRow(label: "Acidic D+E / Basic K+R+H / Aromatic F+W+Y", value: "\(r.acidicCount) / \(r.basicCount) / \(r.aromaticCount)")
                    ResultRow(label: "Trp / Tyr / Cys", value: "\(r.counts["W", default: 0]) / \(r.counts["Y", default: 0]) / \(r.counts["C", default: 0])")
                }
                if !optionsFirst { ProteinOptionsView(model:model) }
                switch Result(catching: { try ProteinModificationCalculator.calculate(model.input,options:model.options) }) {
                case .failure(let error): CalculationFailure(error:error)
                case .success(let modified):
                    ResultRow(label:"Modification ΔMass (including termini / disulfides)",value:"\(numeric(modified.deltaMass, digits:4)) Da")
                    ResultRow(label:"Final theoretical MW",value:"\(numeric(modified.finalMW, digits:4)) Da / \(numeric(modified.finalMW/1000, digits:4)) kDa",identifier:"protein.mwResult")
                    ResultRow(label:"Total Cys / Disulfides",value:"\(r.counts["C",default:0]) / \(modified.disulfides)")
                    ResultRow(label:"Estimated ε₂₈₀",value:"\(numeric(modified.extinction)) M⁻¹ cm⁻¹",identifier:"protein.extinctionResult")
                    CopyButton(title:"Copy modified summary",text:"Base MW: \(modified.baseMW) Da\nΔMass: \(modified.deltaMass) Da\nFinal theoretical MW: \(modified.finalMW) Da\nDisulfides: \(modified.disulfides)\nEstimated epsilon280: \(modified.extinction) M^-1 cm^-1\nBase pI (NOT modification-adjusted): \(r.isoelectricPoint)")
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
