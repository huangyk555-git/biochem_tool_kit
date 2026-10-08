import Foundation
/// Deterministic inputs shared by portable checks and XCTest; no random fixtures.
public enum TestFixtures {
    public static let publishedPrimer = "CGTTCCAAAGATGTGGGCATGAGCTTAC"
    public static let hairpin = "GCGCGCAAAAGCGCGC"
    public static let protein = "MACKSTYWCCC"
    public static let mixedFASTA = ">中文, sample\r\nAT GC\r\n\r\n>bad\r\nATGN\r\n>third\r\nGGCC\r\n"
}
