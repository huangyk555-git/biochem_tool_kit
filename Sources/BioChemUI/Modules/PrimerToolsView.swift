import SwiftUI
import BioChemCore

struct PrimerToolsView: View {
    var pairMode = false
    @State private var input = ""
    @State private var reverse = ""
    @State private var salt = "50"
    @State private var concentration = "250"
    @State private var concentrationUnit: ConcentrationUnit = .nanomolar
    @State private var method: PrimerTmMethod = .auto
    @State private var advanced = false
    private func tm(_ sequence: String) throws -> TmEstimate {
        // Unused condition fields must not block Wallace or Basic calculations.
        let selected = method == .auto ? (SequenceUtilities.normalize(sequence).count < 14 ? PrimerTmMethod.wallace : .nearestNeighbor) : method
        let n = selected == .nearestNeighbor ? try UnitConverter.convert(UnitConverter.number(concentration,field:"Primer concentration"),from:concentrationUnit,to:.nanomolar) : 250
        let s = selected == .wallace ? 50 : try UnitConverter.number(salt,field:"Monovalent salt")
        return try PrimerTmCalculator.calculate(sequence,method:method,primerNanomolar:n,saltMillimolar:s)
    }
    var body: some View {
        ToolPage(title: pairMode ? "Primer Pair Analyzer" : "Primer Analyzer", subtitle: "Estimated / theoretical value · 标准 DNA A/T/G/C，5′ → 3′") {
            SequenceInput(title: pairMode ? "Forward primer" : "DNA primer sequence",text:$input,identifier:pairMode ? "pair.forwardInput" : "primer.sequenceInput")
            if pairMode { SequenceInput(title:"Reverse primer",text:$reverse,identifier:"pair.reverseInput") }
            Picker("Calculation method",selection:$method) { ForEach(PrimerTmMethod.allCases) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("primer.methodPicker")
            Button { advanced.toggle() } label: {
                Label("Advanced Settings",systemImage:advanced ? "chevron.down" : "chevron.right")
            }.buttonStyle(.plain).accessibilityIdentifier("primer.advanced")
                .accessibilityValue(advanced ? "Expanded" : "Collapsed")
            if advanced {
                HStack {
                    Text("Primer concentration")
                    TextField("250",text:$concentration).textFieldStyle(.roundedBorder).frame(width:110).accessibilityIdentifier("primer.concentrationInput")
                    Picker("单位",selection:$concentrationUnit) { Text("nM").tag(ConcentrationUnit.nanomolar); Text("μM").tag(ConcentrationUnit.micromolar) }.frame(width:100)
                    Text("Monovalent salt (mM)")
                    TextField("50",text:$salt).textFieldStyle(.roundedBorder).frame(width:95).accessibilityIdentifier("primer.saltInput")
                }.padding(.vertical,8)
                Text("NN 假设完全互补的等摩尔双链：浓度指每条链；自互补序列指该链总浓度。盐按 Na⁺ 等效单价盐；未实现 Mg²⁺、dNTP、错配及添加剂修正。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if pairMode { pairResults } else { singleResults }
            Text("Auto：<14 nt 使用 Wallace（Simple estimate），否则 NN（2–200 nt）。Basic 为 GC/Na⁺ 经验式，≥14 nt。所有结果仅作快速参考，不保证实际 PCR 性能。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var singleResults: some View {
        switch Result(catching:{ try PrimerCalculator.analyze(input) }) {
        case .failure(let error): CalculationFailure(error:error)
        case .success(let r):
            ResultRow(label:"Length",value:"\(r.dna.length) nt",identifier:"primer.lengthResult")
            ResultRow(label:"A / T / G / C",value:"ATGC".map { String(r.dna.counts[$0,default:0]) }.joined(separator:" / "))
            ResultRow(label:"GC / AT %",value:"\(numeric(r.dna.gcPercent))% / \(numeric(r.dna.atPercent))%",identifier:"primer.gcResult")
            ResultRow(label:"Estimated molecular weight",value:"\(numeric(r.molecularWeight)) g/mol")
            switch Result(catching:{ try tm(input) }) {
            case .failure(let error): CalculationFailure(error:error)
            case .success(let estimate):
                ResultRow(label:"Estimated Tm",value:"\(numeric(estimate.value)) °C",identifier:"primer.tmResult")
                ResultRow(label:"Method",value:estimate.method.rawValue)
                ResultRow(label:"Conditions",value:estimate.method == .wallace ? "Salt / concentration not used" : estimate.method == .basic ? "Na⁺ \(salt) mM; primer concentration not used" : "Primer \(concentration) \(concentrationUnit.rawValue); Na⁺ \(salt) mM")
                if let nn = estimate.thermodynamics {
                    ResultRow(label:"ΔH / ΔS (before salt)",value:"\(numeric(nn.deltaH)) kcal/mol / \(numeric(nn.deltaS)) cal/(mol K)")
                }
                CopyButton(title:"Copy summary",text:"Sequence: \(r.dna.sequence)\nLength: \(r.dna.length)\nGC: \(r.dna.gcPercent)%\nAT: \(r.dna.atPercent)%\nCounts A/T/G/C: \("ATGC".map { String(r.dna.counts[$0,default:0]) }.joined(separator:"/"))\nEstimated MW: \(r.molecularWeight) g/mol\nEstimated Tm: \(estimate.value) °C\nMethod: \(estimate.method.rawValue)\nPrimer concentration: \(concentration) \(concentrationUnit.rawValue); salt: \(salt) mM (used only by applicable methods)")
            }
            HStack { CopyButton(title:"Copy sequence",text:r.dna.sequence); CopyButton(title:"Copy reverse complement",text:r.dna.reverseComplement) }
            SequenceOutput(title:"Sequence · 5′→3′",sequence:r.dna.sequence)
            SequenceOutput(title:"Reverse",sequence:r.dna.reversed)
            SequenceOutput(title:"Complement · 3′→5′",sequence:r.dna.complement)
            SequenceOutput(title:"Reverse complement · 5′→3′",sequence:r.dna.reverseComplement)
            StructureSection(title:"Hairpin",result:Result { try PrimerSecondaryStructureAnalyzer.hairpin(input) })
            StructureSection(title:"Self-dimer",result:Result { try PrimerSecondaryStructureAnalyzer.dimer(input,input) })
        }
    }
    @ViewBuilder private var pairResults: some View {
        switch Result(catching:{ (try SequenceUtilities.dna(input),try SequenceUtilities.dna(reverse),try tm(input),try tm(reverse)) }) {
        case .failure(let error): CalculationFailure(error:error)
        case .success(let (f,r,ft,rt)):
            ResultRow(label:"Forward · Length / GC / Tm",value:"\(f.length) nt / \(numeric(f.gcPercent))% / \(numeric(ft.value)) °C")
            ResultRow(label:"Reverse · Length / GC / Tm",value:"\(r.length) nt / \(numeric(r.gcPercent))% / \(numeric(rt.value)) °C")
            ResultRow(label:"Actual methods · Forward / Reverse",value:"\(ft.method.rawValue) / \(rt.method.rawValue)")
            ResultRow(label:"Conditions (where applicable)",value:"Primer \(concentration) \(concentrationUnit.rawValue); Na⁺ \(salt) mM")
            ResultRow(label:"ΔTm",value:"\(numeric(abs(ft.value-rt.value))) °C",identifier:"pair.deltaTm")
            ResultRow(label:"Estimated recommendation · Annealing range",value:"\(numeric(min(ft.value,rt.value)-5))–\(numeric(min(ft.value,rt.value)-3)) °C")
            if ft.method != rt.method { Text("Auto 选择了不同方法；建议选择同一方法后比较 Tm。").foregroundStyle(.orange) }
            Text("退火范围仅为较低 Tm 减 5 至减 3 °C 的经验起点；ΔTm >5 °C 应重新评估。请结合聚合酶体系和梯度 PCR 验证。")
                .font(.caption).foregroundStyle(.secondary)
            StructureSection(title:"Hetero-dimer",result:Result { try PrimerSecondaryStructureAnalyzer.dimer(input,reverse) })
            StructureSection(title:"Forward hairpin",result:Result { try PrimerSecondaryStructureAnalyzer.hairpin(input) })
            StructureSection(title:"Reverse hairpin",result:Result { try PrimerSecondaryStructureAnalyzer.hairpin(reverse) })
            StructureSection(title:"Forward self-dimer",result:Result { try PrimerSecondaryStructureAnalyzer.dimer(input,input) })
            StructureSection(title:"Reverse self-dimer",result:Result { try PrimerSecondaryStructureAnalyzer.dimer(reverse,reverse) })
        }
    }
}
struct StructureSection: View {
    let title: String
    let result: Result<SecondaryStructureResult,Error>
    var body: some View {
        GroupBox(title + " · heuristic estimate") {
            switch result {
            case .failure(let error): CalculationFailure(error:error)
            case .success(let r):
                ResultRow(label:"Risk / 3′ risk",value:"\(r.risk.title) / \(r.threePrimeRisk.title)")
                ResultRow(label:"Longest stretch / paired bases / GC pairs",value:"\(r.longestStretch) / \(r.totalPairs) / \(r.gcPairs)")
                ResultRow(label:"Maximum 3′ stretch",value:"\(r.threePrimeStretch)")
                if let loop = r.loopLength { ResultRow(label:"Loop length",value:"\(loop) nt") }
                ScrollView(.horizontal) { Text(r.alignment).font(.system(.caption,design:.monospaced)).fixedSize().textSelection(.enabled) }
                Text("无 ΔG；仅连续 Watson–Crick 互补，不计错配/凸环。显示最长候选 alignment；3′ 风险汇总所有候选，可能来自另一 alignment。High：≥8 bp，或 ≥6 bp 且含 ≥4 GC，或 3′ 连续 ≥4 bp；Moderate：≥4 bp 或 3′ ≥2 bp。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityIdentifier("structure."+title)
    }
}
