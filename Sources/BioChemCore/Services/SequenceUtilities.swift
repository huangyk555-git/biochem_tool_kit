import Foundation

public enum SequenceUtilities {
    public static let maximumLength = 100_000
    public static let complementMap: [Character: Character] = ["A": "T", "T": "A", "G": "C", "C": "G"]
    /// Only ASCII lowercase is folded; Unicode lookalikes never become valid residues.
    public static func normalize(_ input: String) -> String {
        String(input.filter { !$0.isWhitespace }.map { c -> Character in
            guard let value = c.asciiValue, (97...122).contains(value) else { return c }
            return Character(UnicodeScalar(value - 32))
        })
    }
    private static func validate(_ sequence: String, alphabet: Set<Character>) throws -> String {
        guard !sequence.isEmpty else { throw AnalysisError.emptySequence }
        guard sequence.count <= maximumLength else { throw AnalysisError.tooLong }
        let invalid = Set(sequence.filter { !alphabet.contains($0) }).map(String.init).sorted()
        guard invalid.isEmpty else { throw AnalysisError.invalidCharacters(invalid.prefix(12).joined(separator: ", ")) }
        return sequence
    }
    public static func dna(_ input: String) throws -> DNAResult {
        let sequence = try validate(normalize(input), alphabet: Set("ATGC"))
        return DNAResult(sequence: sequence, counts: sequence.reduce(into: [:]) { $0[$1, default: 0] += 1 })
    }
    public static func protein(_ input: String) throws -> String {
        var headerCount = 0
        var sequence = ""
        for line in input.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">") {
                headerCount += 1
                guard headerCount <= 1 else { throw AnalysisError.multipleFASTA }
                guard sequence.isEmpty else { throw AnalysisError.malformedFASTA }
            } else { sequence += normalize(line) }
        }
        return try validate(sequence, alphabet: Set(ProteinConstants.residueMasses.keys))
    }
    public static func translate(_ input: String, frame: Int = 1, stopAtStop: Bool = true) throws -> TranslationResult {
        guard (1...3).contains(frame) else { throw AnalysisError.invalidNumber("Reading frame（1–3）") }
        let sequence = Array(try dna(input).sequence)
        var output = "", stop: Int?
        let offset = frame - 1
        let usable = max(0, sequence.count - offset)
        let codons = usable / 3
        for index in 0..<codons {
            let start = offset + index * 3
            let codon = String(sequence[start..<(start + 3)])
            let amino = GeneticCode.standard[codon]!
            if amino == "*", stopAtStop { stop = index + 1; break }
            output.append(amino)
        }
        return TranslationResult(protein: output, frame: frame, trailingBases: usable % 3, stoppedAtCodon: stop)
    }
}
