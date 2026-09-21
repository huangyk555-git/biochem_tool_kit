import Foundation
import CoreGraphics
import BioChemCore
import BioChemTestSupport

struct CheckFailure: Error, CustomStringConvertible { let description: String }
var count = 0
func check(_ name: String, _ condition: @autoclosure () throws -> Bool) throws {
    guard try condition() else { throw CheckFailure(description: name) }
    count += 1
    print("PASS \(name)")
}
func rejected(_ json: [String: Any]) throws -> Bool {
    let value = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
    do { try value.validate(); return false } catch { return true }
}

do {
    let catalog = try Catalog.bundled()
    try check("20 standard amino acids", catalog.entries.filter { $0.kind == .aminoAcid }.count == 20)
    try check("24 functional groups", catalog.entries.filter { $0.kind == .functionalGroup }.count == 24)
    for query in ["酪氨酸", "TYROSINE", "Tyr", "y", "  Y\n"] {
        try check("search \(query.trimmingCharacters(in: .whitespacesAndNewlines))", catalog.search(query, kind: .aminoAcid).first?.id == "tyrosine")
    }
    try check("single-letter R is exact", catalog.search("R", kind: .aminoAcid).map(\.id) == ["arginine"])
    try check("unknown amino-acid code", catalog.search("B", kind: .aminoAcid).isEmpty)
    try check("no results", catalog.search("不存在", kind: .aminoAcid).isEmpty)
    try check("empty search", catalog.search(" \n ", kind: .aminoAcid).count == 20)
    try check("Chinese alias", catalog.search("蛋氨酸", kind: .aminoAcid).first?.id == "methionine")
    try check("multiple tokens", catalog.search("芳香族 极性不带电", kind: .aminoAcid).map(\.id) == ["tyrosine"])
    try check("acidic category", catalog.search("", kind: .aminoAcid, category: "负电").count == 2)
    try check("functional-group alias", catalog.search("Schiff", kind: .functionalGroup).map(\.id) == ["imine"])
    try check("combined category and text", catalog.search("羰基", kind: .functionalGroup, category: "含氮").map(\.id) == ["amide", "oxime"])
    for (code, expected) in [("D", -1), ("E", -1), ("K", 1), ("R", 1), ("H", 0), ("C", 0), ("Y", 0)] {
        try check("charge \(code)", catalog.entries.first { $0.oneLetter == code }?.chargePH7?.predominant == expected)
    }
    try check("histidine partial protonation", catalog.entries.first { $0.oneLetter == "H" }!.chargePH7!.label.contains("部分正电"))
    try check("proline cyclic backbone", catalog.entries.first { $0.oneLetter == "P" }!.formula.contains("回接 N"))
    try check("glycine achiral", catalog.entries.first { $0.oneLetter == "G" }!.summary.contains("无手性"))
    for entry in catalog.entries where entry.structureAsset != nil {
        let url = Catalog.structureURL(named: entry.structureAsset!)!
        try check("SVG \(entry.id)", try String(contentsOf: url).contains("<svg"))
    }
    try check("asset path traversal rejected", Catalog.structureURL(named: "../catalog.json") == nil)
    let original = try JSONSerialization.jsonObject(with: JSONEncoder().encode(catalog)) as! [String: Any]
    var changed = original; changed["schemaVersion"] = 999
    try check("bad version rejected", try rejected(changed))
    changed = original
    var entries = original["entries"] as! [[String: Any]]
    entries.append(entries[0]); changed["entries"] = entries
    try check("duplicate ID rejected", try rejected(changed))
    entries = original["entries"] as! [[String: Any]]
    entries[0]["structureAsset"] = "missing.svg"; changed["entries"] = entries
    try check("missing SVG rejected", try rejected(changed))
    entries.removeFirst(); changed["entries"] = entries
    try check("incomplete amino acids rejected", try rejected(changed))
    var right = RightClickMenuGate()
    try check("right outside pet passes through", right.handle(.down, at: .zero, isTarget: false, hasModifiers: false) == .passThrough)
    try check("unclaimed release passes through", right.handle(.up, at: .zero, isTarget: true, hasModifiers: false) == .passThrough)
    try check("Option right click preserves host menu", right.handle(.down, at: .zero, isTarget: true, hasModifiers: true) == .passThrough)
    try check("Option release passes through", right.handle(.up, at: .zero, isTarget: true, hasModifiers: true) == .passThrough)
    try check("matched right press consumes without opening", right.handle(.down, at: .zero, isTarget: true, hasModifiers: false) == .consume)
    try check("left and hover events pass through", right.handle(.other, at: .zero, isTarget: true, hasModifiers: false) == .passThrough)
    try check("right release opens menu", right.handle(.up, at: CGPoint(x: 1, y: 1), isTarget: true, hasModifiers: false) == .showMenu)
    try check("release cannot open duplicate menu", right.handle(.up, at: .zero, isTarget: true, hasModifiers: false) == .passThrough)
    _ = right.handle(.down, at: .zero, isTarget: true, hasModifiers: false)
    try check("claimed right drag consumed", right.handle(.dragged, at: CGPoint(x: 10, y: 0), isTarget: false, hasModifiers: false) == .consume)
    try check("drag returning to pet cannot open menu", right.handle(.up, at: .zero, isTarget: true, hasModifiers: false) == .consume)
    _ = right.handle(.down, at: .zero, isTarget: true, hasModifiers: false)
    try check("release outside consumes pair without menu", right.handle(.up, at: .zero, isTarget: false, hasModifiers: false) == .consume)
    _ = right.handle(.down, at: .zero, isTarget: true, hasModifiers: false)
    try check("modifier added before release cancels menu", right.handle(.up, at: .zero, isTarget: true, hasModifiers: true) == .consume)
    _ = right.handle(.down, at: .zero, isTarget: true, hasModifiers: false)
    right.cancel()
    try check("pause cancels pending menu", right.handle(.up, at: .zero, isTarget: true, hasModifiers: false) == .passThrough)
    try check("unclaimed right drag passes through", right.handle(.dragged, at: .zero, isTarget: true, hasModifiers: false) == .passThrough)
    try check("binding allows Codex", PetBindingRules.ownerBundleIDs.contains("com.openai.codex"))
    try check("binding rejects other apps", !PetBindingRules.ownerBundleIDs.contains("com.apple.Safari"))
    try check("binding allows small image", PetBindingRules.suitable(role: "AXImage", width: 120, height: 160))
    try check("binding rejects input fields", !PetBindingRules.suitable(role: "AXTextField", width: 120, height: 160))
    try check("binding rejects window", !PetBindingRules.suitable(role: "AXWindow", width: 120, height: 160))
    try check("binding rejects large group", !PetBindingRules.suitable(role: "AXGroup", width: 1440, height: 900))
    try check("binding rejects tiny controls", !PetBindingRules.suitable(role: "AXButton", width: 20, height: 20))
    try check("binding rejects invalid size", !PetBindingRules.suitable(role: "AXImage", width: .infinity, height: 160))
    try check("binding rejects very wide toolbar", !PetBindingRules.suitable(role: "AXGroup", width: 400, height: 50))
    let originalWindow = CGRect(x: 100, y: 200, width: 500, height: 500)
    let region = PetRegionAnchor(window: originalWindow, point: CGPoint(x: 250, y: 350))!
    try check("region stays small", region.relative.width == 100 && region.relative.height == 120)
    try check("region follows window movement", region.resolve(in: CGRect(x: 200, y: 300, width: 500, height: 500))?.origin == CGPoint(x: 300, y: 390))
    try check("region invalidates on resize", region.resolve(in: CGRect(x: 100, y: 200, width: 600, height: 500)) == nil)
    try check("region rejects clicks outside window", PetRegionAnchor(window: originalWindow, point: CGPoint(x: 0, y: 0)) == nil)
    try check("region clips to window", PetRegionAnchor(window: originalWindow, point: CGPoint(x: 110, y: 210))!.relative.minX == 0)
    for test in AnalysisChecks.all {
        try test.run()
        try check(test.name, true)
    }
    print("\(count) checks passed.")
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
