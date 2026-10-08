import Foundation

public struct FASTARecord: Identifiable {
    public let id: Int
    public let name: String
    public let sequence: String
    public let error: String?
    public init(id: Int, name: String, sequence: String, error: String? = nil) {
        self.id = id; self.name = name; self.sequence = sequence; self.error = error
    }
}
public enum FASTAParser {
    public static let maximumBytes = 10_000_000
    public static let maximumRecords = 10_000
    public static func parse(_ text: String) throws -> [FASTARecord] {
        guard text.utf8.count <= maximumBytes else { throw ToolError.invalid("FASTA 文件最多 10 MB。") }
        var records: [FASTARecord] = [], name: String?, sequence = "", error: String?
        func finish() {
            guard let name else { return }
            records.append(FASTARecord(id: records.count, name: name, sequence: sequence,
                error: error ?? (sequence.isEmpty ? "Empty FASTA record" : nil)))
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix(">") {
                finish()
                guard records.count < maximumRecords else { throw ToolError.invalid("最多 10,000 条 FASTA 记录。") }
                let header = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                name = header.isEmpty ? "Unnamed record \(records.count+1)" : header
                error = header.isEmpty ? "Empty FASTA header" : nil
                sequence = ""
            } else {
                if name == nil { name = "Before first header"; error = "Sequence before FASTA header" }
                sequence += SequenceUtilities.normalize(trimmed)
            }
        }
        finish()
        guard text.split(whereSeparator: \.isNewline).contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(">") }), !records.isEmpty else {
            throw ToolError.invalid("No valid FASTA record found；需要以 > 开始的 header。")
        }
        return records
    }
    public static func singleSequence(_ input: String) throws -> String {
        guard input.contains(">") else { return input }
        let records = try parse(input)
        guard records.count == 1 else { throw AnalysisError.multipleFASTA }
        guard let record = records.first else { throw AnalysisError.emptySequence }
        if let error = record.error { throw ToolError.invalid(error) }
        return record.sequence
    }
}
