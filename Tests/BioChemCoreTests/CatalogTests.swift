import XCTest
@testable import BioChemCore

final class CatalogTests: XCTestCase {
    func testBundledCatalogAndAllResourcesLoad() throws {
        let catalog = try Catalog.bundled()
        XCTAssertEqual(catalog.entries.filter { $0.kind == .aminoAcid }.count, 20)
        XCTAssertEqual(catalog.entries.filter { $0.kind == .functionalGroup }.count, 24)
        for entry in catalog.entries {
            if let asset = entry.structureAsset {
                let url = try XCTUnwrap(Catalog.structureURL(named: asset))
                XCTAssertTrue(try String(contentsOf: url).contains("<svg"))
            }
        }
        XCTAssertNil(Catalog.structureURL(named: "../catalog.json"))
    }
    func testChineseEnglishAndAbbreviationsFindTyrosine() throws {
        let catalog = try Catalog.bundled()
        for query in ["酪氨酸", "TYROSINE", "Tyr", "y", "  Y\n"] {
            XCTAssertEqual(catalog.search(query, kind: .aminoAcid).first?.id, "tyrosine", query)
        }
    }
    func testSingleLetterDoesNotMatchUnrelatedEnglishNames() throws {
        let catalog = try Catalog.bundled()
        XCTAssertEqual(catalog.search("R", kind: .aminoAcid).map(\.id), ["arginine"])
        XCTAssertTrue(catalog.search("B", kind: .aminoAcid).isEmpty)
        XCTAssertTrue(catalog.search("不存在", kind: .aminoAcid).isEmpty)
    }
    func testCategoryTokensAndAliases() throws {
        let catalog = try Catalog.bundled()
        XCTAssertEqual(catalog.search("蛋氨酸", kind: .aminoAcid).first?.id, "methionine")
        XCTAssertEqual(catalog.search("芳香族 极性不带电", kind: .aminoAcid).map(\.id), ["tyrosine"])
        XCTAssertEqual(catalog.search("", kind: .aminoAcid, category: "负电").count, 2)
        XCTAssertEqual(catalog.search("Schiff", kind: .functionalGroup).map(\.id), ["imine"])
        XCTAssertEqual(catalog.search("羰基", kind: .functionalGroup, category: "含氮").map(\.id), ["amide", "oxime"])
        XCTAssertEqual(catalog.search(" \n ", kind: .aminoAcid).count, 20)
    }
    func testChargeConventionsAndSpecialBackbones() throws {
        let entries = try Catalog.bundled().entries
        for (code, charge) in [("D", -1), ("E", -1), ("K", 1), ("R", 1), ("H", 0), ("C", 0), ("Y", 0)] {
            XCTAssertEqual(entries.first { $0.oneLetter == code }?.chargePH7?.predominant, charge)
        }
        let his = try XCTUnwrap(entries.first { $0.oneLetter == "H" })
        XCTAssertTrue(his.chargePH7!.label.contains("部分正电"))
        XCTAssertTrue(entries.first { $0.oneLetter == "P" }!.formula.contains("回接 N"))
        XCTAssertTrue(entries.first { $0.oneLetter == "G" }!.summary.contains("无手性"))
    }
    func testInvalidCatalogFailsWithHelpfulError() throws {
        let catalog = try Catalog.bundled()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(catalog)) as? [String: Any])
        json["schemaVersion"] = 999
        let invalid = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try invalid.validate()) { XCTAssertTrue($0.localizedDescription.contains("版本")) }
        json["schemaVersion"] = 1
        var entries = try XCTUnwrap(json["entries"] as? [[String: Any]])
        entries.append(entries[0]); json["entries"] = entries
        let duplicate = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try duplicate.validate())
    }
    func testMissingAminoAcidAndMissingSVGAreRejected() throws {
        let catalog = try Catalog.bundled()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(catalog)) as? [String: Any])
        var entries = try XCTUnwrap(json["entries"] as? [[String: Any]])
        entries[0]["structureAsset"] = "missing.svg"
        json["entries"] = entries
        let missingSVG = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try missingSVG.validate())
        entries.removeFirst(); json["entries"] = entries
        let missingAmino = try JSONDecoder().decode(Catalog.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try missingAmino.validate())
    }
}
