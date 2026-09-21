# Changelog

## 0.5.0

- Add Primer / Oligo Tools: normalized DNA, composition, mass, reverse complement, Wallace and salt-adjusted GC Tm, and paired-primer annealing estimates.
- Add Protein Analyzer: single FASTA, theoretical MW and Bjellqvist pI, composition, residue counts, average residue mass and estimated extinction coefficients.
- Add DNA transformations and standard-code translation with three reading frames and optional stop behavior.
- Add dilution and molarity/mass calculators with typed unit conversion.
- Group navigation and pet context menus; preserve reference content, search, optional pet binding and close/quit actions.
- Add light/dark/system appearance selection and copyable results; keep sequence inputs in memory only.
- Add 26 shared calculation check groups plus XCTest wrappers, preserving 62 existing command-line regression checks.
- Document calculation assumptions, constants, references and the CLT-only XCTest limitation.
- Pure Swift implementation; no new external dependencies. Local ad-hoc build only, no official distribution or release assets.
