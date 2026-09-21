import Foundation

/// NCBI translation table 1; no alternative initiation-codon reinterpretation.
/// https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1
public enum GeneticCode {
    public static let standard: [String: Character] = {
        let bases = Array("TCAG")
        let amino = Array("FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG")
        var table: [String: Character] = [:]
        var i = 0
        for first in bases { for second in bases { for third in bases {
            table[String([first, second, third])] = amino[i]
            i += 1
        } } }
        return table
    }()
}
