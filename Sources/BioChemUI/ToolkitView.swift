import SwiftUI

public enum ToolDestination: String, CaseIterable, Identifiable {
    case reference, primer, dna, translation, protein, dilution, molarity
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .reference: return "Reference · 氨基酸 / 官能团"
        case .primer: return "Primer Tools"
        case .dna: return "DNA Tools"
        case .translation: return "Translation"
        case .protein: return "Protein Analyzer"
        case .dilution: return "Dilution"
        case .molarity: return "Molarity / Mass"
        }
    }
}

struct ToolkitView: View {
    @AppStorage("BioChem.appearance") private var appearance = "system"
    @ObservedObject var session: BioChemSession
    let onOpenSettings: (() -> Void)?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("BioChem", selection: $session.destination) {
                    Section("Reference") { Text(ToolDestination.reference.title).tag(ToolDestination.reference) }
                    Section("Sequence") {
                        ForEach([ToolDestination.primer, .dna, .translation]) { Text($0.title).tag($0) }
                    }
                    Section("Protein") { Text(ToolDestination.protein.title).tag(ToolDestination.protein) }
                    Section("Calculators") {
                        ForEach([ToolDestination.dilution, .molarity]) { Text($0.title).tag($0) }
                    }
                }.pickerStyle(.menu).frame(width: 340).accessibilityLabel("工具页面")
                Spacer()
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }.labelsHidden().frame(width: 110).accessibilityLabel("外观")
                if let onOpenSettings { Button(action: onOpenSettings) { Label("设置", systemImage: "gearshape") } }
            }.padding(.horizontal, 20).padding(.vertical, 10)
            Divider()
            // Keep editor state when navigating; inactive pages cannot receive input.
            ZStack {
                page(.reference) { BioChemView(session: session) }
                page(.primer) { PrimerToolsView() }
                page(.dna) { SequenceToolsView(translation: false) }
                page(.translation) { SequenceToolsView(translation: true) }
                page(.protein) { ProteinToolsView() }
                page(.dilution) { DilutionToolsView() }
                page(.molarity) { MolarityToolsView() }
            }
        }.frame(minWidth: 780, minHeight: 650)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
            .onChange(of: session.destination) { _ in NSApp.keyWindow?.makeFirstResponder(nil) }
    }
    private func page<V: View>(_ destination: ToolDestination, @ViewBuilder content: () -> V) -> some View {
        content().opacity(session.destination == destination ? 1 : 0)
            .allowsHitTesting(session.destination == destination)
            .disabled(session.destination != destination)
            .accessibilityHidden(session.destination != destination)
    }
}
