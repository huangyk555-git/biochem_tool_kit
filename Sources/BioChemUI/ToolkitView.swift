import SwiftUI

public enum ToolDestination: String, CaseIterable, Identifiable {
    case reference, primer, primerPair, dna, translation, protein, proteinOptions, batch, dilution, molarity
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .reference: return "Reference · 氨基酸 / 官能团"
        case .primer: return "Primer Analyzer"
        case .primerPair: return "Primer Pair"
        case .proteinOptions: return "Protein Options"
        case .batch: return "FASTA Analyzer"
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
    @StateObject private var protein = ProteinWorkspace()
    @ObservedObject var session: BioChemSession
    let onOpenSettings: (() -> Void)?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("biochem_tool_kit", selection: $session.destination) {
                    Section("Reference") { Text(ToolDestination.reference.title).tag(ToolDestination.reference) }
                    Section("DNA & Primer") {
                        ForEach([ToolDestination.primer, .primerPair, .dna, .translation]) { Text($0.title).tag($0) }
                    }
                    Section("Protein") { ForEach([ToolDestination.protein, .proteinOptions]) { Text($0.title).tag($0) } }
                    Section("Batch") { Text(ToolDestination.batch.title).tag(ToolDestination.batch) }
                    Section("Calculators") {
                        ForEach([ToolDestination.dilution, .molarity]) { Text($0.title).tag($0) }
                    }
                }.pickerStyle(.menu).frame(width: 390).accessibilityLabel("工具页面").accessibilityIdentifier("navigation.toolPicker")
                Spacer()
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }.labelsHidden().frame(width: 110).accessibilityLabel("外观").accessibilityIdentifier("appearance.picker")
                if let onOpenSettings { Button(action: onOpenSettings) { Label("设置", systemImage: "gearshape") } }
            }.padding(.horizontal, 20).padding(.vertical, 10)
            Divider()
            PersistentToolPages(selection:session.destination,pages:[
                (.reference,AnyView(BioChemView(session:session))),
                (.primer,AnyView(PrimerToolsView())),
                (.primerPair,AnyView(PrimerToolsView(pairMode:true))),
                (.dna,AnyView(SequenceToolsView(translation:false))),
                (.translation,AnyView(SequenceToolsView(translation:true))),
                (.protein,AnyView(ProteinToolsView(model:protein))),
                (.proteinOptions,AnyView(ProteinToolsView(model:protein,optionsFirst:true))),
                (.batch,AnyView(BatchToolsView())),
                (.dilution,AnyView(DilutionToolsView())),
                (.molarity,AnyView(MolarityToolsView()))
            ])
        }.frame(minWidth: 780, minHeight: 650)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
            .onChange(of: session.destination) { _ in NSApp.keyWindow?.makeFirstResponder(nil) }
    }
}

/// NSTabView keeps each hosting view/state alive while removing inactive editors
/// from the displayed AppKit hierarchy. The existing menu remains the navigation UI.
private struct PersistentToolPages: NSViewRepresentable {
    let selection: ToolDestination
    let pages: [(ToolDestination,AnyView)]
    func makeNSView(context: Context) -> NSTabView {
        let tabs = NSTabView()
        tabs.tabViewType = .noTabsNoBorder
        tabs.drawsBackground = false
        for (destination,view) in pages {
            let item = NSTabViewItem(identifier:destination.rawValue)
            let host = NSHostingView(rootView:AnyView(view.environment(\.colorScheme,context.environment.colorScheme)))
            host.sizingOptions = []
            item.view = host
            tabs.addTabViewItem(item)
        }
        tabs.selectTabViewItem(withIdentifier:selection.rawValue)
        return tabs
    }
    func updateNSView(_ tabs:NSTabView,context:Context) {
        for (destination,view) in pages {
            if let item = tabs.tabViewItems.first(where: { $0.identifier as? String == destination.rawValue }),
               let host = item.view as? NSHostingView<AnyView> {
                host.rootView = AnyView(view.environment(\.colorScheme,context.environment.colorScheme))
            }
        }
        tabs.selectTabViewItem(withIdentifier:selection.rawValue)
    }
}
