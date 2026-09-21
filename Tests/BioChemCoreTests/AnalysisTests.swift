import XCTest
import BioChemTestSupport

final class AnalysisTests: XCTestCase {
    private func run(_ checks: [AnalysisCheck]) {
        for check in checks {
            do { try check.run() }
            catch { XCTFail("\(check.name): \(error)") }
        }
    }
    func testPrimer() { run(AnalysisChecks.primer) }
    func testProtein() { run(AnalysisChecks.protein) }
    func testSequence() { run(AnalysisChecks.sequence) }
    func testUnitConversionAndSolutions() { run(AnalysisChecks.units) }
}
