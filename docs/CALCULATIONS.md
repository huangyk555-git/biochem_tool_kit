# Calculation methods and assumptions

All calculators run locally in pure Swift without third-party dependencies. Results are **theoretical / estimated values**, intended for quick laboratory reference, experiment preparation, and sequence inspection. They do not replace professional sequence analysis or experimental validation. Source links below document factual constants and algorithms; no network request is made during calculation.

## Input rules

DNA accepts A/T/G/C only, removing whitespace and folding ASCII lowercase. Ambiguous bases, RNA U, punctuation, digits, and Unicode lookalikes are rejected explicitly. Protein accepts the 20 standard single-letter residues, optionally preceded by one FASTA header. Multiple FASTA records are rejected rather than silently concatenated. Protein B/J/O/U/X/Z, gaps, and stop symbols are rejected. Both inputs have a 100,000-character normalized length limit. DNA input fields normalize immediately; protein keeps the original FASTA text in the editor and displays/copies its normalized sequence separately.

## Primer / oligo

`PrimerCalculator` returns both methods (General only for length ≥14), with °C as the temperature unit:

- **Wallace:** `2 × (A+T) + 4 × (G+C)`. A rough short-oligo estimate; it does not adjust for salt or sequence context.
- **General primer:** `77.1 + 0.41 × GC% − 528/N + 11.7 × log10([Na+] in M)`, the von Ahsen et al. (2001) empirical parameter set documented as `Tm_GC` valueset 8 in [Biopython melting-temperature documentation](https://biopython.org/docs/1.80/api/Bio.SeqUtils.MeltingTemp.html). The tool accepts Na⁺ 1–1000 mM and defaults to 50 mM. The ≥14-nt guard is an application safeguard, not a claim that every longer sequence is accurately predicted.

These are not nearest-neighbor thermodynamic calculations. Magnesium, dNTPs, primer concentration, mismatch, hairpins, dimers, buffer chemistry and enzyme-specific recommendations are not modeled. Wallace remains visible at longer lengths for comparison; it is not the recommended method there.

Pair analysis uses the selected method for both primers, entered 5′→3′. `ΔTm = abs(TmF − TmR)`. The suggested annealing range is the **heuristic** `[min(TmF,TmR)−5, min(TmF,TmR)−3] °C`. It is a starting estimate for evaluation, not a PCR prediction; ΔTm >5 °C displays a warning. A polymerase-specific protocol and gradient PCR remain necessary.

Unmodified single-stranded DNA MW (g/mol), assuming free 5′-OH / 3′-OH ends:

`313.21 A + 304.20 T + 329.21 G + 289.18 C − 61.96`

Average nucleotide masses and terminal correction follow [Bio-Synthesis oligonucleotide properties](https://www.biosyn.com/gizmo/tools/oligo/oligonucleotide%20properties%20calculator.htm). Phosphorylation, labels, modifications, counterions and duplexes are not included.

## Protein molecular weight

`ProteinConstants.swift` contains all masses and pKa values. Average isotopic free-amino-acid masses are cross-checked with [Biopython IUPACData](https://github.com/biopython/biopython/blob/master/Bio/Data/IUPACData.py). Water is 18.0153 Da.

`residue mass = free amino acid mass − 18.0153`

`MW = Σ residue masses + 18.0153 = Σ free amino acid masses − (N−1) × 18.0153`

Thus a single amino acid retains its free mass, and every peptide bond accounts for loss of one water molecule. The displayed average residue mass is `Σ residue masses / N`, explicitly excluding terminal water. Da per molecule and g/mol have the same numerical value here. This is an unmodified linear, reduced protein with free N/C termini, without processing, tags, bound molecules, salts or post-translational modifications.

## Protein pI

The Bjellqvist pKa set, including terminal corrections, is documented by [Biopython IsoelectricPoint](https://github.com/biopython/biopython/blob/master/Bio/SeqUtils/IsoelectricPoint.py).

| Ionizable group | pKa |
| --- | ---: |
| N terminus, default | 7.50 |
| C terminus, default | 3.55 |
| Lys | 10.00 |
| Arg | 12.00 |
| His | 5.98 |
| Asp | 4.05 |
| Glu | 4.45 |
| Cys | 9.00 |
| Tyr | 10.00 |

N-terminal residue overrides: A 7.59, M 7.00, S 6.93, P 8.36, T 6.82, V 7.44, E 7.70. C-terminal overrides: D 4.55, E 4.75.

For each basic group, charge contribution is `count / (1 + 10^(pH−pKa))`; for each acidic group it is `−count / (1 + 10^(pKa−pH))`. There is one N terminus and one C terminus. Net charge includes all these termini and the D/E/C/Y/H/K/R side chains. After verifying the root is bracketed, 60 bisection steps in pH 0–14 find net charge ≈0. UI rounds pI to two decimals; numerical convergence is not experimental accuracy.

Acidic residue count is D+E; basic is K+R+H; aromatic is F+W+Y. These composition counts are not net charges at pH 7. pI does not account for local microenvironment, disulfides, modifications or protein folding. See [ExPASy pI/MW limitations](https://web.expasy.org/compute_pi/pi_tool-doc.html).

## Extinction coefficient

Estimated ε₂₈₀ in M⁻¹ cm⁻¹:

- All cysteines reduced: `5500 × Trp + 1490 × Tyr`.
- Maximum possible disulfide pairs: add `125 × floor(Cys/2)`.

These two assumptions follow the constants in [ExPASy ProtParam documentation](https://web.expasy.org/protparam/protparam-doc.html). The second does not predict actual disulfide pairing and does not alter the reduced MW/pI calculations. Estimates are less reliable without tryptophan.

## DNA and translation

Reverse returns reversed characters. Complement is the antiparallel 3′→5′ strand aligned to the input 5′→3′ sequence; reverse complement is reported 5′→3′. Translation uses [NCBI standard genetic code, table 1](https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1), positive reading frames 1, 2 or 3. Incomplete trailing codons are excluded and counted. Stop-on-stop excludes the first stop and everything after it; otherwise stops appear as `*`. Initiation codons are not reinterpreted as methionine. Negative frames and ORF prediction are not included.

## Solution calculations

`UnitConverter` uses mol/L (M), L and g as base units. `m` means ×10⁻³, `μ` means ×10⁻⁶; molecular weight is g/mol. Conversion occurs before solving, never by mixing raw display units in formulas.

Dilution solves any one of C1/V1/C2/V2 using `C1V1=C2V2`. The other three must be finite and >0. It rejects concentration increases (`C2>C1`) or stock volume larger than final volume (`V1>V2`). Final volume means total volume after dilution, not added solvent volume.

Required mass is `MW × target molarity × final volume`, then converted to g/mg/μg. MW and volume must be >0; concentration may be zero. Purity is assumed 100%; the user must choose the correct salt/hydrate MW. Nonfinite values and unrepresentable results are rejected.

## Verification

`Tests/Support/AnalysisChecks.swift` is shared by XCTest and `BioChemCheck`. It includes independent expected values, invalid inputs, all three frames, stop behavior, conservation of composition, pI net-charge roots, all four dilution unknowns and all combinations of supported molarity/mass units. Reference pI checks include INGAR ≈9.75 and PETER ≈4.53. No external scientific package is required at runtime or to execute these checks.
