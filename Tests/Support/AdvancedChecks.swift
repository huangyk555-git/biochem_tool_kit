import Foundation
import BioChemCore

private func require(_ condition: Bool, _ message: String = "Unexpected result") throws {
    if !condition { throw ToolError.invalid(message) }
}
private func close(_ actual: Double, _ expected: Double, _ tolerance: Double = 1e-8) throws {
    try require(abs(actual-expected) <= tolerance,"Expected \(expected); got \(actual)")
}
private func fails(_ operation: () throws -> Void) throws {
    var rejected = false
    do { try operation() } catch { rejected = true }
    try require(rejected,"Expected rejection")
}
public enum AdvancedChecks {
    public static let all: [AnalysisCheck] = [
        .init(name:"NN published reference and thermodynamic sums") {
            let r = try NearestNeighborTmCalculator.calculate(TestFixtures.publishedPrimer,primerNanomolar:25,saltMillimolar:50)
            try close(r.tm,60.32091949919129)
            try close(r.deltaH,-222.9); try close(r.deltaS,-602.5)
            try close(r.saltEntropy, -29.765595870032453)
        },
        .init(name:"NN independent concentration and salt reference values") {
            try close(try NearestNeighborTmCalculator.calculate(TestFixtures.publishedPrimer,primerNanomolar:250,saltMillimolar:50).tm,62.61919615225872)
            try close(try NearestNeighborTmCalculator.calculate(TestFixtures.publishedPrimer,primerNanomolar:250,saltMillimolar:100).tm,66.13915678840976)
            try close(try NearestNeighborTmCalculator.calculate("ATGCATGCATGCATGCATGC",primerNanomolar:250).tm,58.63359885075522)
        },
        .init(name:"NN all-GC all-AT symmetry and terminal corrections") {
            let gc = try NearestNeighborTmCalculator.calculate("GCGCGCGC",primerNanomolar:250)
            let at = try NearestNeighborTmCalculator.calculate("ATATATAT",primerNanomolar:250)
            try require(gc.selfComplementary && at.selfComplementary)
            try close(gc.tm,42.74797701535965); try close(at.tm,-13.840612829963902)
            try close(gc.deltaH,-70.8); try close(gc.deltaS,-186.2)
            let short = try NearestNeighborTmCalculator.calculate("ATGC")
            try close(short.deltaH,-23.1); try close(short.deltaS,-66.2)
        },
        .init(name:"NN very short, long and invalid conditions") {
            for s in ["", "A", "ATGN",String(repeating:"A",count:201)] { try fails { _ = try NearestNeighborTmCalculator.calculate(s) } }
            for c in [0.0,-1,.infinity,.nan] { try fails { _ = try NearestNeighborTmCalculator.calculate("ATGC",primerNanomolar:c) } }
            for c in [0.0,-1,.infinity,.nan] { try fails { _ = try NearestNeighborTmCalculator.calculate("ATGC",saltMillimolar:c) } }
        },
        .init(name:"Auto resolves method and Wallace ignores salt") {
            let short = try PrimerTmCalculator.calculate("a t\ng c",method:.auto)
            try require(short.method == .wallace); try close(short.value,12)
            try require(try PrimerTmCalculator.calculate(TestFixtures.publishedPrimer).method == .nearestNeighbor)
            try close(try PrimerTmCalculator.calculate("ATGC",method:.wallace,saltMillimolar:.nan).value,12)
            try close(try PrimerTmCalculator.calculate("ATGCATGCATGCATGCATGC",method:.basic).value,55.9779490507314)
        },
        .init(name:"hairpin no complementarity and loop constraint") {
            let r = try PrimerSecondaryStructureAnalyzer.hairpin("AAAAAAAAAAAA")
            try require(r.longestStretch == 0 && r.risk == .low && r.threePrimeStretch == 0)
            try require(try PrimerSecondaryStructureAnalyzer.hairpin("AT").longestStretch == 0)
        },
        .init(name:"strong hairpin stem loop GC and alignment") {
            let r = try PrimerSecondaryStructureAnalyzer.hairpin(TestFixtures.hairpin)
            try require(r.longestStretch == 6 && r.loopLength == 4 && r.gcPairs == 6)
            try require(r.risk == .high && r.threePrimeStretch == 6 && r.threePrimeRisk == .high)
            try require(r.alignment.contains("||||||") && r.alignment.contains("loop 4 nt"))
        },
        .init(name:"self-dimer and strong three-prime heterodimer") {
            let none = try PrimerSecondaryStructureAnalyzer.dimer("AAAAAA","AAAAAA")
            try require(none.risk == .low && none.totalPairs == 0)
            let selfDimer = try PrimerSecondaryStructureAnalyzer.dimer("GCGCGCGC","GCGCGCGC")
            try require(selfDimer.longestStretch == 8 && selfDimer.risk == .high)
            let hetero = try PrimerSecondaryStructureAnalyzer.dimer("AAAACCCC","GGGGTTTT")
            try require(hetero.longestStretch == 8 && hetero.totalPairs == 8 && hetero.gcPairs == 4)
            try require(hetero.threePrimeStretch == 8 && hetero.threePrimeRisk == .high && hetero.alignment.contains("||||||||"))
        },
        .init(name:"secondary length guard and invalid input") {
            try fails { _ = try PrimerSecondaryStructureAnalyzer.hairpin(String(repeating:"A",count:201)) }
            try fails { _ = try PrimerSecondaryStructureAnalyzer.dimer("ATN","ATGC") }
        },
        .init(name:"protein independent mass and pI services") {
            try close(try ProteinMolecularWeightCalculator.calculate("AG"),146.1445)
            try close(try ProteinPICalculator.calculate("A"),5.57)
            try close(try ProteinPICalculator.calculate("INGAR"),9.75,0.01)
            try close(try ProteinPICalculator.calculate("PETER"),4.53,0.01)
            try fails { _ = try ProteinMolecularWeightCalculator.calculate("") }
        },
        .init(name:"modification base mass and N-terminal Met removal") {
            let native = try ProteinModificationCalculator.calculate("MAG",options:ProteinOptions())
            try close(native.baseMW,277.3405); try close(native.deltaMass,0)
            var o = ProteinOptions(); o.nTerm = .removeMet
            let r = try ProteinModificationCalculator.calculate("MAG",options:o)
            try close(r.deltaMass,-131.196); try close(r.finalMW,146.1445)
            try require(r.effectiveSequence == "AG")
            try fails { _ = try ProteinModificationCalculator.calculate("AG",options:o) }
            try fails { _ = try ProteinModificationCalculator.calculate("M",options:o) }
        },
        .init(name:"N acetylation and C amidation average masses") {
            var o = ProteinOptions(); o.nTerm = .acetylated; o.amidated = true
            let r = try ProteinModificationCalculator.calculate("AG",options:o)
            try close(r.deltaMass,41.0519); try close(r.finalMW,187.1964)
        },
        .init(name:"oxidation phosphorylation methylation and acetylation") {
            let cases: [(ModificationKind,String,Double)] = [(.oxidation,"M",15.9994),(.phosphorylation,"S",79.9799),(.methylation,"K",14.0266),(.acetylation,"K",42.0367)]
            for (kind,sequence,mass) in cases {
                var o = ProteinOptions(); o.modifications = [ProteinModification(kind:kind,position:1)]
                let r = try ProteinModificationCalculator.calculate(sequence,options:o)
                try close(r.deltaMass,mass); try close(r.finalMW,r.baseMW+mass)
            }
        },
        .init(name:"multiple modifications retain original positions") {
            var o = ProteinOptions(); o.nTerm = .removeMet
            o.modifications = [.init(kind:.phosphorylation,position:2),.init(kind:.acetylation,position:3),.init(kind:.oxidation,position:4)]
            let r = try ProteinModificationCalculator.calculate("MSKM",options:o)
            try close(r.deltaMass,6.82); try close(r.finalMW,r.baseMW+6.82)
        },
        .init(name:"invalid positions sites duplicates and removed residues") {
            for position in [0,-1,4] {
                var o = ProteinOptions(); o.modifications = [.init(kind:.oxidation,position:position)]
                try fails { _ = try ProteinModificationCalculator.calculate("MAG",options:o) }
            }
            var o = ProteinOptions(); o.modifications = [.init(kind:.oxidation,position:2)]
            try fails { _ = try ProteinModificationCalculator.calculate("MAG",options:o) }
            o.modifications = [.init(kind:.oxidation,position:1),.init(kind:.oxidation,position:1)]
            try fails { _ = try ProteinModificationCalculator.calculate("MAG",options:o) }
            o.modifications.removeLast(); o.nTerm = .removeMet
            try fails { _ = try ProteinModificationCalculator.calculate("MAG",options:o) }
        },
        .init(name:"disulfide zero one multiple maximum and extinction") {
            let s = "WYWCCCCC"
            for n in 0...2 {
                var o = ProteinOptions(); o.disulfide = .custom; o.customDisulfides = n
                let r = try ProteinModificationCalculator.calculate(s,options:o)
                try close(r.deltaMass,-2.01588*Double(n)); try close(r.extinction,12490+125*Double(n))
                try require(r.disulfides == n)
            }
            var o = ProteinOptions(); o.disulfide = .maximum
            try require(try ProteinModificationCalculator.calculate(s,options:o).disulfides == 2)
            o.disulfide = .custom; o.customDisulfides = 3
            try fails { _ = try ProteinModificationCalculator.calculate(s,options:o) }
            o.customDisulfides = -1
            try fails { _ = try ProteinModificationCalculator.calculate(s,options:o) }
        },
        .init(name:"FASTA CRLF LF Unicode multiline blank lines") {
            let records = try FASTAParser.parse(TestFixtures.mixedFASTA)
            try require(records.count == 3 && records[0].name == "中文, sample" && records[0].sequence == "ATGC")
            try require(try FASTAParser.parse(">α\nAG\n CT\n\n").first?.sequence == "AGCT")
            try require(try SequenceUtilities.dnaFASTA(">DNA\nat gc").sequence == "ATGC")
        },
        .init(name:"FASTA malformed records preserved as errors") {
            let r = try FASTAParser.parse("ATGC\n>\nATGC\n>empty\n>valid\nATGC")
            try require(r.count == 4 && r[0].error != nil && r[1].error != nil && r[2].error != nil && r[3].error == nil)
            try fails { _ = try FASTAParser.parse("ATGC") }
            try fails { _ = try FASTAParser.parse("") }
            try fails { _ = try SequenceUtilities.dnaFASTA(">a\nAT\n>b\nGC") }
        },
        .init(name:"batch mixed valid invalid records do not abort") {
            let r = try BatchAnalyzer.analyze(TestFixtures.mixedFASTA,kind:.dna)
            try require(r.count == 3 && r[0].error == nil && r[1].error != nil && r[2].error == nil)
            try require(r[0].values[1] == "4" && r[0].values[2] == "50.0000")
            let p = try BatchAnalyzer.analyze(">AG\nAG\n>bad\nAX\n>INGAR\nINGAR",kind:.protein)
            try require(p[0].values[2] == "146.1445" && p[1].error != nil && p[2].error == nil)
        },
        .init(name:"batch long sequence and stable duplicate header identifiers") {
            let input = ">same\n"+String(repeating:"A",count:100_001)+"\n>same\nATGC"
            let r = try BatchAnalyzer.analyze(input,kind:.dna)
            try require(r[0].error != nil && r[1].error == nil && r[0].id != r[1].id)
        },
        .init(name:"CSV quotes commas Unicode and multiple rows") {
            let csv = SequenceExporter.delimited(headers:["Name","Value"],rows:[["中文,\"a\"","1"],["b","2"]],separator:",")
            try require(csv == "Name,Value\r\n\"中文,\"\"a\"\"\",1\r\nb,2\r\n")
            try require(String(data:Data(csv.utf8),encoding:.utf8) == csv)
        },
        .init(name:"TSV tabs quotes newlines and header") {
            let tsv = SequenceExporter.delimited(headers:["Name","Value"],rows:[["a\tb","line\nnext"],["\"quoted\"","3"]],separator:"\t")
            try require(tsv == "Name\tValue\r\n\"a\tb\"\t\"line\nnext\"\r\n\"\"\"quoted\"\"\"\t3\r\n")
        },
        .init(name:"FASTA export skips invalid preserves Unicode and wrapping") {
            let rows = try BatchAnalyzer.analyze(TestFixtures.mixedFASTA,kind:.dna)
            let output = SequenceExporter.export(rows,kind:.dna,format:.fasta)
            try require(output == ">中文, sample\nATGC\n>third\nGGCC\n")
            try require(try FASTAParser.parse(output).count == 2)
            let long = try BatchAnalyzer.analyze(">long\n"+String(repeating:"A",count:161),kind:.dna)
            let lines = SequenceExporter.export(long,kind:.dna,format:.fasta).split(separator:"\n")
            try require(lines.map(\.count) == [5,80,80,1])
        },
        .init(name:"nM conversion and dilution") {
            try close(try UnitConverter.convert(1000,from:ConcentrationUnit.nanomolar,to:.micromolar),1)
            try close(try UnitConverter.convert(1,from:ConcentrationUnit.millimolar,to:.nanomolar),1e6)
            let r = try SolutionCalculator.dilution(solving:.v1,known:[.c1:1e-6,.c2:100e-9,.v2:0.001])
            try close(r.v1,0.0001)
        }
    ]
}
