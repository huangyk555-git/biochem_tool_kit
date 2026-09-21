import SwiftUI
import AppKit
import BioChemCore

func numeric(_ value: Double, digits: Int = 2) -> String {
    if value != 0 && (abs(value) < 0.001 || abs(value) >= 1e8) { return String(format: "%.4g", value) }
    return value.formatted(.number.precision(.fractionLength(0...digits)))
}
struct CopyButton: View {
    let title: String
    let text: String
    @State private var copied = false
    var body: some View {
        Button(copied ? "已复制" : title) {
            NSPasteboard.general.clearContents()
            copied = NSPasteboard.general.setString(text, forType: .string)
        }.disabled(text.isEmpty).help(title)
            .onChange(of: text) { _ in copied = false }
    }
}
struct ResultRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 14)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled).multilineTextAlignment(.trailing)
            CopyButton(title: "复制", text: value).controlSize(.small)
        }.padding(.vertical, 4)
    }
}
struct SequenceInput: View {
    let title: String
    @Binding var text: String
    var hint: String = "自动忽略空格与换行，并转为大写；非法字符会保留并提示。"
    var normalizeDNA: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            TextEditor(text: $text).font(.system(.body, design: .monospaced))
                .frame(height: 95).padding(5)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                .accessibilityLabel(title)
                .onChange(of: text) { value in
                    if normalizeDNA {
                        let normalized = SequenceUtilities.normalize(value)
                        if normalized != value { text = normalized }
                    }
                }
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct ToolPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title).font(.system(size: 25, weight: .semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                content
            }.padding(24).frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Color(nsColor: .windowBackgroundColor))
    }
}
struct CalculationFailure: View {
    let error: Error
    var body: some View {
        Label(error.localizedDescription, systemImage: "exclamationmark.circle")
            .foregroundStyle(.orange).font(.callout).textSelection(.enabled)
    }
}
struct SequenceOutput: View {
    let title: String
    let sequence: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.headline); Spacer(); CopyButton(title: "复制", text: sequence) }
            Text(sequence.isEmpty ? "—" : sequence).font(.system(.body, design: .monospaced))
                .textSelection(.enabled).lineLimit(8)
            if sequence.count > 80 { Text("最多显示 8 行；复制按钮始终复制完整序列。").font(.caption).foregroundStyle(.secondary) }
        }.padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
