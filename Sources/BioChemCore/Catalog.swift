import Foundation

public enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case aminoAcid, functionalGroup
    public var id: String { rawValue }
    public var title: String { self == .aminoAcid ? "氨基酸" : "官能团" }
}

public struct Charge: Codable, Equatable {
    public let label: String
    public let predominant: Int
    public let note: String
}

public struct BioChemEntry: Codable, Identifiable {
    public let id: String
    public let kind: EntryKind
    public let nameCN: String
    public let nameEN: String
    public let threeLetter: String?
    public let oneLetter: String?
    public let sideChain: String?
    public let formula: String
    public let categories: [String]
    public let chargePH7: Charge?
    public let summary: String
    public let structureAsset: String?
    public let aliases: [String]
    public let sourceIDs: [String]

    public var searchableText: String {
        ([nameCN, nameEN, threeLetter ?? "", oneLetter ?? "", sideChain ?? "", formula,
          summary, chargePH7?.label ?? ""] + categories + aliases).joined(separator: " ")
    }
}

public struct CatalogSource: Codable, Identifiable {
    public let id: String
    public let title: String
    public let url: URL
}

public struct Catalog: Codable {
    public let schemaVersion: Int
    public let chargeConvention: String
    public let sources: [CatalogSource]
    public let entries: [BioChemEntry]

    // Signed macOS applications keep resources under Contents/Resources; SwiftPM
    // executables and library consumers use the generated Bundle.module fallback.
    private static let resourceBundle: Bundle = {
        if let resources = Bundle.main.resourceURL,
           let bundle = Bundle(url: resources.appendingPathComponent("BioChemPet_BioChemCore.bundle")) {
            return bundle
        }
        return Bundle.module
    }()

    public static func bundled() throws -> Catalog {
        guard let url = resourceBundle.url(forResource: "catalog", withExtension: "json", subdirectory: "Resources") else {
            throw CatalogError.invalid("缺少 catalog.json 资源。请重新构建应用。")
        }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> Catalog {
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        try catalog.validate()
        return catalog
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw CatalogError.invalid("不支持的数据版本。") }
        guard Set(entries.map(\.id)).count == entries.count else { throw CatalogError.invalid("条目 ID 重复。") }
        let amino = entries.filter { $0.kind == .aminoAcid }
        guard amino.count == 20, Set(amino.compactMap(\.oneLetter)) == Set("ACDEFGHIKLMNPQRSTVWY".map(String.init)),
              Set(amino.compactMap(\.threeLetter)).count == 20 else {
            throw CatalogError.invalid("需要完整的 20 种标准氨基酸及唯一缩写。")
        }
        let knownSources = Set(sources.map(\.id))
        for entry in entries {
            guard !entry.nameCN.isEmpty, !entry.nameEN.isEmpty, !entry.formula.isEmpty,
                  !entry.categories.isEmpty, !entry.summary.isEmpty,
                  !entry.sourceIDs.isEmpty, Set(entry.sourceIDs).isSubset(of: knownSources) else {
                throw CatalogError.invalid("条目 \(entry.id) 字段不完整。")
            }
            if entry.kind == .aminoAcid {
                guard let side = entry.sideChain, !side.isEmpty, let charge = entry.chargePH7,
                      (-1...1).contains(charge.predominant) else {
                    throw CatalogError.invalid("氨基酸 \(entry.id) 缺少侧链或电性。")
                }
            }
            if let asset = entry.structureAsset {
                guard asset.hasSuffix(".svg"), !asset.contains(".."), !asset.contains("/"),
                      Self.structureURL(named: asset) != nil else {
                    throw CatalogError.invalid("找不到结构式资源：\(asset)")
                }
            }
        }
    }

    public func search(_ query: String, kind: EntryKind, category: String? = nil) -> [BioChemEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = entries.filter { $0.kind == kind && (category == nil || $0.categories.contains(category!)) }
        // A single alphabetic character means the exact amino-acid code, not every English word containing it.
        if kind == .aminoAcid, normalized.count == 1, normalized.range(of: "^[A-Za-z]$", options: .regularExpression) != nil {
            return candidates.filter { $0.oneLetter?.caseInsensitiveCompare(normalized) == .orderedSame }
        }
        let tokens = normalized.split(whereSeparator: \.isWhitespace).map(String.init)
        return candidates.filter { entry in tokens.allSatisfy { entry.searchableText.localizedStandardContains($0) } }
            .sorted { lhs, rhs in
                let leftExact = lhs.threeLetter?.caseInsensitiveCompare(normalized) == .orderedSame
                let rightExact = rhs.threeLetter?.caseInsensitiveCompare(normalized) == .orderedSame
                return leftExact != rightExact ? leftExact : lhs.nameEN < rhs.nameEN
            }
    }

    public static func structureURL(named name: String) -> URL? {
        guard !name.contains("/"), !name.contains("..") else { return nil }
        return resourceBundle.url(forResource: name, withExtension: nil, subdirectory: "Resources/Structures")
    }
}

public enum CatalogError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
