import SwiftUI
import AppKit
import UniformTypeIdentifiers
import BioChemCore

struct BatchToolsView: View {
    @State private var input = ""
    @State private var kind = BatchKind.dna
    @State private var rows: [BatchAnalysisResult] = []
    @State private var message: String?
    @State private var busy = false
    @State private var revision = 0
    @State private var format = ExportFormat.csv
    var body: some View {
        ToolPage(title:"Batch FASTA Analyzer",subtitle:"DNA / Protein · 每条记录单独报告错误，原始序列默认不显示") {
            SequenceInput(title:"Multi-FASTA",text:$input,hint:"粘贴、打开或拖入 .fasta / .fa / .faa / .fna；UTF-8，最多 10 MB / 10,000 条，每条最多 100,000 残基。",normalizeDNA:false,identifier:"batch.fastaInput",onFileDrop:load)
            HStack {
                Picker("Sequence type",selection:$kind) { ForEach(BatchKind.allCases) { Text($0.rawValue).tag($0) } }.frame(width:200).accessibilityIdentifier("batch.kindPicker")
                Button("Open FASTA…",action:openFile).accessibilityIdentifier("batch.open")
                Button(busy ? "Analyzing…" : "Analyze",action:analyze).disabled(busy || input.isEmpty).accessibilityIdentifier("batch.analyze")
                Spacer()
            }
            HStack {
                Picker("Export",selection:$format) { ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) } }.frame(width:130).accessibilityIdentifier("batch.formatPicker")
                CopyButton(title:"Copy batch result",text:SequenceExporter.export(rows,kind:kind,format:format)).disabled(rows.isEmpty)
                Button("Save…",action:save).disabled(rows.isEmpty).accessibilityIdentifier("batch.save")
                Spacer()
            }
            if let message { Text(message).foregroundStyle(.orange).accessibilityIdentifier("batch.error") }
            Text("\(rows.count) records · \(rows.filter { $0.error != nil }.count) errors").accessibilityIdentifier("batch.count")
            ScrollView(.horizontal) {
                VStack(alignment:.leading,spacing:0) {
                    tableRow(BatchAnalyzer.headers(kind),header:true)
                    LazyVStack(alignment:.leading,spacing:0) { ForEach(rows) { row in tableRow(row.values,header:false) } }
                }
            }.accessibilityIdentifier("batch.resultTable")
            Text("CSV/TSV 包含 Error 列；FASTA 仅导出通过验证的记录。FASTA 不包含修饰；Batch Protein 按 native / reduced 计算，不继承单条 Protein Options。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of:input) { _ in invalidate() }.onChange(of:kind) { _ in invalidate() }
        .onDrop(of:[UTType.fileURL.identifier],isTargeted:nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier:UTType.fileURL.identifier,options:nil) { item,error in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation:$0,relativeTo:nil) }
                Task { @MainActor in if let url { load(url) } else { message = error?.localizedDescription ?? "无法读取拖拽文件。" } }
            }
            return true
        }
    }
    private func tableRow(_ cells:[String],header:Bool) -> some View {
        HStack(alignment:.top,spacing:10) {
            ForEach(Array(cells.enumerated()),id:\.offset) { index,text in
                Text(text).font(header ? .headline : .system(.body,design:.monospaced)).textSelection(.enabled)
                    .lineLimit(3).help(text).frame(width:index == 0 || index == cells.count-1 ? 220 : 90,alignment:.leading)
            }
        }.padding(8).background(header ? Color.secondary.opacity(0.12) : .clear)
    }
    private func invalidate() { revision += 1; rows = []; message = nil; busy = false }
    private func analyze() {
        revision += 1; let token = revision, text = input, selected = kind
        busy = true; message = nil
        Task {
            let result = await Task.detached(priority:.userInitiated) { Result { try BatchAnalyzer.analyze(text,kind:selected) } }.value
            guard revision == token else { return }
            busy = false
            switch result { case .success(let value): rows = value; case .failure(let error): rows = []; message = error.localizedDescription }
        }
    }
    private func openFile() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.allowedContentTypes = ["fasta","fa","faa","fna"].compactMap { UTType(filenameExtension:$0) }
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for:window) { response in
            if response == .OK, let url = panel.url { load(url) }
        }
    }
    private func load(_ url:URL) {
        guard ["fasta","fa","faa","fna"].contains(url.pathExtension.lowercased()) else { message = "仅支持 FASTA 扩展名。"; return }
        revision += 1; let token = revision
        Task {
            let result = await Task.detached(priority:.userInitiated) { () -> Result<String,Error> in
                Result {
                    let file = try FileHandle(forReadingFrom:url); defer { try? file.close() }
                    let data = try file.read(upToCount:FASTAParser.maximumBytes+1) ?? Data()
                    guard data.count <= FASTAParser.maximumBytes, let text = String(data:data,encoding:.utf8) else { throw ToolError.invalid("需要 ≤10 MB 的 UTF-8 文件。") }
                    return text
                }
            }.value
            guard revision == token else { return }
            switch result { case .success(let text): input = text; case .failure(let error): message = error.localizedDescription }
        }
    }
    private func save() {
        let content = SequenceExporter.export(rows,kind:kind,format:format)
        guard !content.isEmpty else { message = "没有可导出的有效 FASTA 记录。"; return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "biochem_tool_kit."+format.rawValue.lowercased()
        panel.allowedContentTypes = [UTType(filenameExtension:format.rawValue.lowercased()) ?? .plainText]
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for:window) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try content.write(to:url,atomically:true,encoding:.utf8) }
            catch { message = error.localizedDescription }
        }
    }
}
