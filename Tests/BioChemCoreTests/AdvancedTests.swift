import XCTest
import BioChemTestSupport

final class AdvancedTests: XCTestCase {
    func testNNPublishedReference() throws { try AdvancedChecks.all[0].run() }
    func testNNConcentrationAndSalt() throws { try AdvancedChecks.all[1].run() }
    func testNNSymmetryAndTermini() throws { try AdvancedChecks.all[2].run() }
    func testNNInvalidConditions() throws { try AdvancedChecks.all[3].run() }
    func testTmAutoSelection() throws { try AdvancedChecks.all[4].run() }
    func testHairpinNoComplementarity() throws { try AdvancedChecks.all[5].run() }
    func testHairpinStrongStem() throws { try AdvancedChecks.all[6].run() }
    func testSelfAndHeteroDimer() throws { try AdvancedChecks.all[7].run() }
    func testSecondaryInputLimits() throws { try AdvancedChecks.all[8].run() }
    func testProteinServices() throws { try AdvancedChecks.all[9].run() }
    func testMetRemoval() throws { try AdvancedChecks.all[10].run() }
    func testTerminalModifications() throws { try AdvancedChecks.all[11].run() }
    func testCommonModifications() throws { try AdvancedChecks.all[12].run() }
    func testMultipleModifications() throws { try AdvancedChecks.all[13].run() }
    func testInvalidModificationSites() throws { try AdvancedChecks.all[14].run() }
    func testDisulfidesAndExtinction() throws { try AdvancedChecks.all[15].run() }
    func testFASTAFormats() throws { try AdvancedChecks.all[16].run() }
    func testFASTAMalformedRecords() throws { try AdvancedChecks.all[17].run() }
    func testBatchPartialFailure() throws { try AdvancedChecks.all[18].run() }
    func testBatchLongRecords() throws { try AdvancedChecks.all[19].run() }
    func testCSVEncoding() throws { try AdvancedChecks.all[20].run() }
    func testTSVEncoding() throws { try AdvancedChecks.all[21].run() }
    func testFASTAExport() throws { try AdvancedChecks.all[22].run() }
    func testNanomolarUnits() throws { try AdvancedChecks.all[23].run() }
}
