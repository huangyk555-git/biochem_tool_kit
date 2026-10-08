import Foundation

public enum BatchKind: String, CaseIterable, Identifiable { case dna = "DNA", protein = "Protein"; public var id: String { rawValue } }
public struct BatchAnalysisResult: Identifiable {
    public let record: FASTARecord
    public let values: [String]
    public let error: String?
    public var id: Int { record.id }
}
public enum BatchAnalyzer {
    public static func headers(_ kind: BatchKind) -> [String] {
        kind == .dna ? ["Name","Length","GC%","A","T","G","C","Error"] : ["Name","Length","MW (Da)","pI","Acidic","Basic","Cys","Trp","Tyr","Error"]
    }
    public static func analyze(_ text: String, kind: BatchKind) throws -> [BatchAnalysisResult] {
        try FASTAParser.parse(text).map { record in
            do {
                if let error = record.error { throw ToolError.invalid(error) }
                let values: [String]
                if kind == .dna {
                    let r = try SequenceUtilities.dna(record.sequence)
                    values = [record.name,String(r.length),decimal(r.gcPercent)] + "ATGC".map { String(r.counts[$0,default:0]) }
                } else {
                    let r = try ProteinCalculator.analyze(record.sequence)
                    values = [record.name,String(r.length),decimal(r.molecularWeight),decimal(r.isoelectricPoint),String(r.acidicCount),String(r.basicCount)] + "CWY".map { String(r.counts[$0,default:0]) }
                }
                return BatchAnalysisResult(record: record, values: values + [""], error: nil)
            } catch {
                return BatchAnalysisResult(record: record, values: [record.name] + Array(repeating:"",count:headers(kind).count-2) + [error.localizedDescription], error: error.localizedDescription)
            }
        }
    }
    private static func decimal(_ number: Double) -> String { String(format: "%.4f", locale: Locale(identifier:"en_US_POSIX"), number) }
}
public enum ExportFormat: String, CaseIterable, Identifiable { case csv = "CSV", tsv = "TSV", fasta = "FASTA"; public var id: String { rawValue } }
public enum SequenceExporter {
    public static func delimited(headers: [String], rows: [[String]], separator: Character) -> String {
        func cell(_ text: String) -> String {
            if text.contains(separator) || text.contains("\"") || text.contains("\n") || text.contains("\r") {
                return "\"" + text.replacingOccurrences(of:"\"",with:"\"\"") + "\""
            }
            return text
        }
        return ([headers] + rows).map { $0.map(cell).joined(separator:String(separator)) }.joined(separator:"\r\n") + "\r\n"
    }
    public static func export(_ rows: [BatchAnalysisResult], kind: BatchKind, format: ExportFormat) -> String {
        if format != .fasta { return delimited(headers:BatchAnalyzer.headers(kind),rows:rows.map(\.values),separator:format == .csv ? "," : "\t") }
        return rows.filter { $0.error == nil }.map { row in
            let letters = Array(row.record.sequence)
            let lines = stride(from:0,to:letters.count,by:80).map { String(letters[$0..<min($0+80,letters.count)]) }
            let header = row.record.name.replacingOccurrences(of:"\n",with:" ").replacingOccurrences(of:"\r",with:" ")
            return ">" + header + "\n" + lines.joined(separator:"\n") + "\n"
        }.joined()
    }
}
