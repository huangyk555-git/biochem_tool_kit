import Foundation
public enum ProteinModificationCalculator {
    public static let hydrogenPairMass = 2.01588
    public static let amidationShift = -0.9848
    public static func calculate(_ input: String, options: ProteinOptions) throws -> ModifiedProteinResult {
        let sequence = try SequenceUtilities.protein(input), residues = Array(sequence)
        let base = try ProteinMolecularWeightCalculator.calculate(sequence)
        var delta = 0.0, effective = sequence
        switch options.nTerm {
        case .native: break
        case .acetylated: delta += ModificationKind.acetylation.massShift
        case .removeMet:
            guard sequence.first == "M", sequence.count > 1, let mass = ProteinConstants.residueMasses["M"] else {
                throw ToolError.invalid("移除 N-terminal Met 要求首位为 M，且至少保留一个残基。")
            }
            delta -= mass; effective = String(sequence.dropFirst())
        }
        if options.amidated { delta += amidationShift }
        var positions = Set<Int>()
        for modification in options.modifications {
            guard (1...residues.count).contains(modification.position),
                  !(options.nTerm == .removeMet && modification.position == 1),
                  positions.insert(modification.position).inserted else {
                throw ToolError.invalid("修饰位置无效、已移除，或同一残基重复修饰：\(modification.position)。")
            }
            guard modification.kind.targetResidues.contains(residues[modification.position-1]) else {
                throw ToolError.invalid("\(modification.kind.rawValue) 本轮仅支持 \(modification.kind.targetResidues)；位置 \(modification.position) 不匹配。")
            }
            delta += modification.kind.massShift
        }
        let cys = effective.filter { $0 == "C" }.count
        let bonds: Int
        switch options.disulfide { case .reduced: bonds = 0; case .custom: bonds = options.customDisulfides; case .maximum: bonds = cys / 2 }
        guard (0...(cys/2)).contains(bonds) else { throw ToolError.invalid("Disulfide 数必须为 0…\(cys/2)；Total Cys = \(cys)。") }
        delta -= Double(bonds) * hydrogenPairMass
        let trp = effective.filter { $0 == "W" }.count
        let tyr = effective.filter { $0 == "Y" }.count
        let epsilon = Double(trp * 5500 + tyr * 1490 + bonds * 125)
        return ModifiedProteinResult(baseMW:base,deltaMass:delta,finalMW:base+delta,disulfides:bonds,extinction:epsilon,effectiveSequence:effective)
    }
}
