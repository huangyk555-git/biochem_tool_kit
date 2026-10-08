import Foundation

public enum StructureRisk: Int, Comparable {
    case low, moderate, high
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    public var title: String { switch self { case .low: return "Low"; case .moderate: return "Moderate"; case .high: return "High" } }
}
public struct SecondaryStructureResult {
    public let longestStretch: Int
    public let totalPairs: Int
    public let gcPairs: Int
    public let threePrimeStretch: Int
    public let loopLength: Int?
    public let risk: StructureRisk
    public let alignment: String
    public var threePrimeRisk: StructureRisk { threePrimeStretch >= 4 ? .high : threePrimeStretch >= 2 ? .moderate : .low }
}
public enum PrimerSecondaryStructureAnalyzer {
    public static let maximumLength = 200
    // Heuristic screening only, no ΔG. High: ≥8 contiguous pairs, or ≥6 with ≥4 GC,
    // or ≥4 pairs contiguous from either 3′ end. Moderate: ≥4 pairs or ≥2 at 3′.
    private static func risk(stem: Int, gc: Int, end: Int) -> StructureRisk {
        if stem >= 8 || (stem >= 6 && gc >= 4) || end >= 4 { return .high }
        if stem >= 4 || end >= 2 { return .moderate }
        return .low
    }
    private static func bases(_ sequence: String) throws -> [Character] {
        let dna = try SequenceUtilities.dna(sequence)
        guard dna.length <= maximumLength else { throw ToolError.invalid("二级结构规则筛查最多 200 nt；未计算长序列风险。") }
        return Array(dna.sequence)
    }
    private static func matches(_ a: Character, _ b: Character) -> Bool { SequenceUtilities.complementMap[a] == b }
    public static func hairpin(_ sequence: String) throws -> SecondaryStructureResult {
        let b = try bases(sequence)
        var best = SecondaryStructureResult(longestStretch: 0, totalPairs: 0, gcPairs: 0, threePrimeStretch: 0, loopLength: nil, risk: .low, alignment: "No complementary stem with loop ≥3 nt.")
        guard b.count >= 5 else { return best }
        for left in 0..<(b.count - 4) {
            for right in (left + 4)..<b.count {
                var length = 0, gc = 0
                while right - left - 2 * length - 1 >= 3 && matches(b[left+length], b[right-length]) {
                    if b[left+length] == "G" || b[left+length] == "C" { gc += 1 }
                    length += 1
                }
                guard length > 0 else { continue }
                let end = right == b.count - 1 ? length : 0
                let level = risk(stem: length, gc: gc, end: end)
                // Keep the longest stem; global risk/3′ warning include every candidate.
                let globalRisk = max(best.risk, level), globalEnd = max(best.threePrimeStretch, end)
                if length > best.longestStretch || (length == best.longestStretch && gc > best.gcPairs) {
                    let loop = right - left - 2 * length + 1
                    let top = String(b[left..<(left+length)])
                    let bottom = String(b[(right-length+1)...right].reversed())
                    best = SecondaryStructureResult(longestStretch: length, totalPairs: length, gcPairs: gc, threePrimeStretch: globalEnd, loopLength: loop, risk: globalRisk,
                        alignment: "5′ \(top)  [loop \(loop) nt]\n   \(String(repeating: "|", count: length))\n3′ \(bottom)\nStem positions: \(left+1)–\(left+length), \(right-length+2)–\(right+1)")
                } else {
                    best = SecondaryStructureResult(longestStretch: best.longestStretch, totalPairs: best.totalPairs, gcPairs: best.gcPairs, threePrimeStretch: globalEnd, loopLength: best.loopLength, risk: globalRisk, alignment: best.alignment)
                }
            }
        }
        return best
    }
    public static func dimer(_ first: String, _ second: String) throws -> SecondaryStructureResult {
        let a = try bases(first), b = Array(try bases(second).reversed())
        var maximum = 0, maximumEnd = 0, globalRisk = StructureRisk.low
        var selected: (run: Int, total: Int, gc: Int, shift: Int, marks: String) = (0,0,0,0,"")
        for shift in (1-b.count)..<a.count {
            var run = 0, longest = 0, total = 0, gc = 0, runGC = 0, end = 0
            var alignmentRisk = StructureRisk.low
            var marks = Array(repeating: Character(" "), count: max(a.count, shift + b.count) - min(0,shift))
            for x in max(0,shift)..<min(a.count,shift+b.count) {
                if matches(a[x], b[x-shift]) {
                    run += 1; total += 1
                    let isGC = a[x] == "G" || a[x] == "C"
                    if isGC { gc += 1; runGC += 1 }
                    longest = max(longest,run)
                    marks[x-min(0,shift)] = "|"
                    if x == a.count-1 { end = max(end,run) }
                    // b's 3′ is its first displayed base; a run starting there includes it.
                    if x-shift-run+1 == 0 { end = max(end,run) }
                    alignmentRisk = max(alignmentRisk,risk(stem:run,gc:runGC,end:end))
                } else { run = 0; runGC = 0 }
            }
            maximum = max(maximum,longest); maximumEnd = max(maximumEnd,end)
            globalRisk = max(globalRisk,alignmentRisk)
            if longest > selected.run || (longest == selected.run && total > selected.total) {
                selected = (longest,total,gc,shift,String(marks))
            }
        }
        let top = String(repeating:" ", count:max(0,-selected.shift)) + String(a)
        let bottom = String(repeating:" ", count:max(0,selected.shift)) + String(b)
        return SecondaryStructureResult(longestStretch: maximum, totalPairs: selected.total, gcPairs: selected.gc,
            threePrimeStretch: maximumEnd, loopLength: nil, risk: globalRisk,
            alignment: "5′ \(top) 3′\n   \(selected.marks)\n3′ \(bottom) 5′")
    }
}
