# biochem_tool_kit Changelog

## Unreleased — 0.6.0

- Unify visible app name, About, menu text, panel titles, permission help and local app bundle name as `biochem_tool_kit`; retain bundle identity and internal Swift module names.
- Add pure Swift SantaLucia NN Tm, explicit method/conditions, separate primer pair page and heuristic hairpin/self-dimer/hetero-dimer screening.
- Add DNA FASTA input, base counts and nM units; preserve reference data, translation and pet interactions.
- Split protein MW/pI services; add average-mass modifications and explicit disulfide options linked to MW and extinction.
- Add asynchronous multi-FASTA analysis, file opening/drop, per-record errors and native CSV/TSV/FASTA export.
- Add a native Xcode project/shared scheme reusing the existing XCTest target plus `biochem_tool_kitUITests`; deterministic fixtures, stable accessibility identifiers and retained Light/Dark screenshot attachments.
- Add 24 portable advanced check groups and optional independent scientific cross-check script.
- Add MIT License at the owner's request.
- Native Xcode 27.0 Debug/Release builds and all 35 XCTest methods pass. Fixed local app/package architecture mismatch and app-target/executable name collision. Added batch-result copying and stable copy identifiers; strengthened UI input confirmation.
- Keep inactive pages out of the visible native view hierarchy while preserving their state; use a native sequence editor for reliable input and file drops.
- Fix accessibility result updates, advanced-settings expansion and long result wrapping. Validate real clipboard contents and UTF-8 files from native open/save panels.
- Select the exact Finder fixture window through its native Window menu, capture destination geometry before switching apps, close it before removing fixtures, and wait for native file-panel confirmation buttons. Stabilize Finder drag coordinates and scoped test keyboard selection; macOS 27 SCIM caused a captured system file-panel-service crash. Restore keyboard and clipboard after tests.
- Final validation on 2026-10-08: Debug/Release PASS, XCTest 35/35, XCUITest 10/10, portable checks 112/112, Biopython 1.85 comparisons 60/60; Light/Dark screenshots inspected. See VALIDATION.md. No Release/DMG/Developer ID/notarization.

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
