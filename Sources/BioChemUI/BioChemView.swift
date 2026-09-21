import SwiftUI
import WebKit
import BioChemCore

@MainActor
public final class BioChemSession: ObservableObject {
    @Published public var destination: ToolDestination = .reference
    @Published public var kind: EntryKind = .aminoAcid
    @Published public var query = ""
    @Published public var category = "全部"
    @Published public var selectedID: String? = "alanine"
    public let catalog: Catalog
    public init(catalog: Catalog) { self.catalog = catalog }
    public var results: [BioChemEntry] { catalog.search(query, kind: kind, category: category == "全部" ? nil : category) }
    public var selected: BioChemEntry? { results.first { $0.id == selectedID } ?? results.first }
    public var categories: [String] {
        ["全部"] + Set(catalog.entries.filter { $0.kind == kind }.flatMap(\.categories)).sorted()
    }
    public func switchTo(_ kind: EntryKind) {
        destination = .reference
        self.kind = kind; query = ""; category = "全部"; selectedID = nil
    }
}

public struct BioChemView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var ink: Color { colorScheme == .dark ? Color(red: 0.60, green: 0.87, blue: 0.79) : Color(red: 0.09, green: 0.28, blue: 0.25) }
    private var paper: Color { colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(red: 0.97, green: 0.97, blue: 0.94) }
    private var card: Color { colorScheme == .dark ? Color(nsColor: .controlBackgroundColor) : .white }

    @ObservedObject private var session: BioChemSession
    @FocusState private var searchFocused: Bool
    private let onOpenSettings: (() -> Void)?
    public init(session: BioChemSession, onOpenSettings: (() -> Void)? = nil) {
        self.session = session
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "atom").font(.system(size: 29, weight: .light))
                VStack(alignment: .leading, spacing: 3) {
                    Text("BioChem").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("随手查一点生物化学").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("20 氨基酸  /  24 官能团").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                if let onOpenSettings {
                    Button(action: onOpenSettings) {
                        Label("设置", systemImage: "gearshape")
                    }.help("设置与可选桌宠连接").accessibilityIdentifier("biochem-settings")
                }
            }.padding(.horizontal, 24).padding(.vertical, 18)
            HStack(spacing: 8) {
                ForEach(EntryKind.allCases) { kind in
                    Button { session.switchTo(kind) } label: {
                        Text(kind.title).font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 19).padding(.vertical, 9)
                            .background(session.kind == kind ? ink : card.opacity(0.7), in: Capsule())
                            .foregroundStyle(session.kind == kind ? paper : ink)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Image(systemName: "wifi.slash").font(.system(size: 10))
                Text("离线资料库").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.bottom, 18)
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: 242)
                Divider()
                if let entry = session.selected {
                    detail(entry).id(entry.id)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 30))
                        Text("没有匹配条目").font(.headline)
                        Text("试试中文、英文或氨基酸缩写").font(.caption).foregroundStyle(.secondary)
                        Button("清除搜索与分类") { session.query = ""; session.category = "全部" }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack {
                Text("⌘F 搜索").font(.system(size: 10))
                Spacer()
                Text("pH 7 · 侧链主要电性 · 分类可重叠").font(.system(size: 10))
            }.foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 10)
        }
        .foregroundStyle(ink).background(paper)
        .frame(minWidth: 780, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .bioChemFocusSearch)) { _ in searchFocused = true }
    }

    private var sidebar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("名称 / Tyr / Y", text: $session.query).textFieldStyle(.plain)
                    .focused($searchFocused).accessibilityLabel("搜索资料")
                if !session.query.isEmpty {
                    Button { session.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("清除搜索")
                }
            }.padding(10).background(card, in: RoundedRectangle(cornerRadius: 9))
            Picker("分类", selection: $session.category) {
                ForEach(session.categories, id: \.self) { Text($0).tag($0) }
            }.font(.system(size: 12))
            HStack {
                Text("\(session.results.count) 个条目").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(session.results) { entry in
                            Button { session.selectedID = entry.id } label: {
                                HStack(spacing: 10) {
                                    Text(entry.oneLetter ?? "•").font(.system(size: 18, weight: .medium, design: .rounded))
                                        .frame(width: 30, height: 35)
                                        .background(ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.nameCN).font(.system(size: 13, weight: .medium))
                                        Text(entry.threeLetter.map { "\($0) · \(entry.nameEN)" } ?? entry.nameEN)
                                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(session.selected?.id == entry.id ? ink.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).id(entry.id)
                        }
                    }
                }.onChange(of: session.query) { _ in if let first = session.results.first { proxy.scrollTo(first.id, anchor: .top) } }
            }
        }.padding(14).background(card.opacity(0.35))
    }

    private func detail(_ entry: BioChemEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.nameEN.uppercased()).font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.nameCN).font(.system(size: 29, weight: .semibold))
                        Spacer()
                        if let three = entry.threeLetter, let one = entry.oneLetter {
                            Text("\(three) / \(one)").font(.system(size: 19, weight: .medium, design: .monospaced))
                        }
                    }
                    Text(entry.categories.joined(separator: "  ·  ")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.kind == .aminoAcid ? "SIDE CHAIN  /  侧链" : "STRUCTURE  /  通式")
                        .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1)
                    Text(entry.sideChain ?? entry.formula).font(.system(size: 23, weight: .medium))
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if let asset = entry.structureAsset, let url = Catalog.structureURL(named: asset) {
                        SVGView(url: url).frame(height: 146).clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel(entry.formula)
                    } else if entry.kind == .aminoAcid {
                        Divider()
                        Text(entry.formula).font(.system(size: 16)).textSelection(.enabled)
                        Text(entry.id == "proline" ? "游离态环状骨架；侧链末端回接 α-氮。" : "游离态骨架示意 · R 表示上方侧链；未表达立体化学。")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.padding(19).frame(maxWidth: .infinity, alignment: .leading)
                    .background(card.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                if let charge = entry.chargePH7 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("pH 7 侧链电性").font(.system(size: 11)).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Circle().fill(charge.predominant < 0 ? Color.orange : charge.predominant > 0 ? Color.blue : ink).frame(width: 7, height: 7)
                            Text(charge.label).font(.system(size: 17, weight: .semibold))
                        }
                        Text(charge.note).font(.system(size: 12)).lineSpacing(4).foregroundStyle(.secondary)
                    }
                }
                Text(entry.summary).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled)
                if entry.kind == .functionalGroup {
                    Text("通式用于识别连接关系，不表达立体化学；R / R′ 通常表示有机取代基，特殊情况见条目说明。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Divider()
                if entry.kind == .aminoAcid {
                    DisclosureGroup("电性与分类说明") {
                        Text(session.catalog.chargeConvention).font(.system(size: 11)).lineSpacing(4).padding(.top, 7)
                    }.font(.system(size: 11))
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("资料来源").font(.system(size: 10)).foregroundStyle(.secondary)
                    ForEach(session.catalog.sources.filter { entry.sourceIDs.contains($0.id) }) { source in
                        Link(source.title, destination: source.url).font(.system(size: 10)).tint(ink)
                    }
                }
            }.padding(27).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SVGView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        guard view.url != url else { return }
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

extension Notification.Name {
    public static let bioChemFocusSearch = Notification.Name("BioChem.FocusSearch")
}
