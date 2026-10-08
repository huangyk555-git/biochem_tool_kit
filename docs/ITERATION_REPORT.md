# biochem_tool_kit — iteration acceptance report

## Overall status

Final local acceptance passed on 2026-10-08: native Debug/Release, 35/35 XCTest, 10/10 XCUITest in one complete run, 112 portable checks and 60 Biopython 1.85 comparisons. Light/Dark screenshots were inspected. Source/staged safety is checked before committing; the actual Git commit and push outcome is reported separately. See [validation evidence](../VALIDATION.md).

## Naming

Canonical user-visible name: `biochem_tool_kit`. Updated main window, reference header, navigation, About, menu-bar tooltip/app menu, pet context menu, settings window, accessibility permission help, local app path, CFBundleName/CFBundleDisplayName, README and validation/change records.

`local.biochem.bridge` remains the bundle identifier. BioChemCore/BioChemUI/BioChemPet/BioChemCheck/BioChemTestSupport/BioChemCoreTests remain internal module/target/executable names. The package name stays BioChemPet to preserve generated resource-bundle identity. `BioChem.appearance` and `BioChem.FocusSearch` remain internal persistence/notification keys. Existing ignored app/audit copies are not deleted or renamed. These are intentional old-name residues, not visible product branding in the new app.

## Features

The feature table describes implementation scope. Complete unit/UI acceptance is recorded below; scientific limitations remain explicit.

| Feature | Implementation / validation scope |
| --- | --- |
| Primer Analyzer | Implemented; normalization, counts, all requested transforms, copy; core checks pass |
| Wallace Tm | Implemented; fixed and independent numeric checks pass |
| Basic Tm | Implemented; fixed and independent numeric checks pass |
| Nearest Neighbor Tm | Implemented; ΔH/ΔS, units, terminal/symmetry, salt/concentration tests and independent checks pass |
| Primer Pair | Implemented; lengths, GC, actual methods, ΔTm and estimate; targeted UI scenario passed |
| Hairpin | Implemented heuristic contiguous stems, ≥3-nt loop, GC, 3′, alignment; deterministic checks pass |
| Self-dimer | Implemented ungapped complementary alignment and risk; deterministic checks pass |
| Hetero-dimer | Implemented including 3′ weighting; deterministic checks pass |
| DNA Tools | Raw/single FASTA, counts/transforms/copy implemented |
| Translation | Standard table, +1/+2/+3, stop/through-stop preserved and tested |
| Protein MW | Independent average-residue service; water/terminal accounting tested |
| Protein pI | Independent Bjellqvist charge/bisection service; native sequence only |
| Extinction | Implemented and linked to selected disulfides; standard chromophore assumption |
| Protein modifications | Terminal options and four explicit residue modifications; mass and error checks pass |
| Disulfides | Reduced/default, custom, maximum; mass/extinction linkage and count checks pass |
| Batch FASTA | Paste/open/drop, background parse/analysis, per-record errors; core checks pass; native open/drop tests passed |
| CSV export | UTF-8 header/rows/quoting implemented and serialization tested; native save test passed |
| TSV export | UTF-8 header/rows/quoting implemented and serialization tested; native save test passed |
| FASTA export | Valid records only, Unicode headers, 80-column wrapping tested; native save test passed |
| Dilution calculator | Preserved, nM added, unit/error checks pass |
| Molarity / Mass | Preserved, typed conversion and combinations checked |

## Scientific methods

- Wallace: 2(A+T)+4(G+C). Basic: 77.1+0.41 GC%−528/N+11.7 log10(Na mol/L).
- NN: SantaLucia 1998 unified Table 2; initiation per terminal pair, self-complementary entropy −1.4 cal/(mol K); salt entropy +0.368(N−1)ln(Na mol/L). Tm = 1000ΔH/(ΔS+ΔSsalt+Rln(Ceffective))−273.15, R=1.987. C is per-strand input; Ceffective=C/2 for non-self-complementary equimolar strands, C for one self-complementary species.
- Protein native MW: sum average residue masses +18.0153 Da; pI: Bjellqvist pKa including terminal corrections, Henderson–Hasselbalch net charge, 60-step bisection in pH 0–14.
- ε280: 5500W+1490Y+125×selected S–S bonds.
- Average modification shifts: acetyl +42.0367, phospho +79.9799, oxidation +15.9994, methyl +14.0266, C-amide −0.9848 Da. N-Met removal subtracts residue mass 131.1960 Da. Disulfide: −2.01588 Da/bond.
- Parameters, conventions, public references and numeric fixtures are in [Calculation Methods](CALCULATIONS.md). No website implementation was copied; no new app runtime dependency.

## Tests and UI regression

- XCTest: 35 executed, 35 passed, 0 failed in the final complete run.
- Portable checks: 112 passed in Debug and Release.
- Scientific comparison: 60 passed with Biopython 1.85.
- XCUITest: 7 original + 3 additional tests preserved; 10 executed, 10 passed, 0 failed in one final complete run.
- Native panels: all four FASTA extensions opened; CSV/TSV/FASTA files saved and read back as exact UTF-8, including Chinese headers and quoted delimiters.
- Finder file drop passed three consecutive complete runs after explicit file selection, a shorter initial drag hold, and closing the fixture window before deleting its folder. Six clipboard flows passed.
- Visual review covered 47 final app screenshots in Light/Dark. Long method names and thermodynamic units now display fully. Empty/error/long-input states and vertical scrolling were inspected; horizontal-table scrolling and modified-result captures were also inspected.

Actual fixes include native target/package name and architecture alignment, source snapshots for isolated Xcode builds, native retained tab pages instead of hidden overlapping editors, NSTextView input/drop and accessibility notifications, updated result values, expandable settings, stable copy identifiers and batch copy. Tests now scroll interactive controls into view without requiring static text to be hittable; Finder drag endpoints are resolved relative to its explicitly selected fixture window. Native file confirmation waits until the Open/Save button is enabled and hittable, then clicks it; back-to-back Return events had raced directory navigation.

The earlier Documents and XCTest identity prompts were approved normally. A later native save failure has a concrete crash report: Apple's `com.apple.appkit.xpc.openAndSavePanelService` raised EXC_BREAKPOINT in AppKit text-input handling, with an SCIM input-method thread. The app stayed running. Tests select an ASCII-capable keyboard temporarily and restore the user's keyboard afterward; the complete file scenario then passed. This is an automation workaround for the observed system crash, not a fix to macOS or proof of the historical tool-specific native-pipe error. No security setting is disabled.

Code-review fixes during the iteration include consistent NN concentration semantics, GC risk from the same pairing run, method-specific input validation, shared protein option state, revision guards against stale file results, and removal of calculation-layer forced unwraps.

## Build

The final native Debug/test/Release script passed all stages for arm64. App deployment target is macOS 13; native test targets require macOS 14 for the current XCTest framework. Builds use local ad-hoc signing. The script stores an exact source snapshot and DerivedData in a temporary workspace and copies genuine test results into ignored `work/`; no global developer-tool or security settings change. This does not establish Universal Binary or public distribution readiness.

## Files

### Added Swift files

- `Sources/BioChemCore/Data/ThermodynamicParameters.swift`
- `Sources/BioChemCore/Models/ProteinModification.swift`
- `Sources/BioChemCore/Services/BatchAnalyzer.swift`
- `Sources/BioChemCore/Services/FASTAParser.swift`
- `Sources/BioChemCore/Services/NearestNeighborTmCalculator.swift`
- `Sources/BioChemCore/Services/PrimerSecondaryStructureAnalyzer.swift`
- `Sources/BioChemCore/Services/PrimerTmCalculator.swift`
- `Sources/BioChemCore/Services/ProteinModificationCalculator.swift`
- `Sources/BioChemCore/Services/ProteinMolecularWeightCalculator.swift`
- `Sources/BioChemCore/Services/ProteinPICalculator.swift`
- `Sources/BioChemUI/Modules/NativeSequenceEditor.swift`
- `Sources/BioChemUI/Modules/BatchToolsView.swift`
- `Sources/BioChemUI/Modules/ProteinOptionsView.swift`
- `Tests/BioChemCoreTests/AdvancedTests.swift`
- `Tests/Support/AdvancedChecks.swift`
- `Tests/Support/ScientificAudit.swift`
- `Tests/Support/TestFixtures.swift`
- `UITests/biochem_tool_kitUITests.swift`

### Modified Swift files

- `Checks/main.swift`
- `Package.swift`
- `Sources/BioChemCore/Catalog.swift`
- `Sources/BioChemCore/Models/AnalysisModels.swift`
- `Sources/BioChemCore/Models/CalculatorModels.swift`
- `Sources/BioChemCore/Services/PrimerCalculator.swift`
- `Sources/BioChemCore/Services/ProteinCalculator.swift`
- `Sources/BioChemCore/Services/SequenceUtilities.swift`
- `Sources/BioChemPet/App.swift`
- `Sources/BioChemPet/NativePetBridge.swift`
- `Sources/BioChemUI/BioChemPanelController.swift`
- `Sources/BioChemUI/BioChemView.swift`
- `Sources/BioChemUI/Modules/CalculatorsView.swift`
- `Sources/BioChemUI/Modules/PrimerToolsView.swift`
- `Sources/BioChemUI/Modules/ProteinToolsView.swift`
- `Sources/BioChemUI/Modules/SequenceToolsView.swift`
- `Sources/BioChemUI/Modules/ToolComponents.swift`
- `Sources/BioChemUI/ToolkitView.swift`

### Other changes

- New native Xcode project/shared scheme, `Config/Info.plist`, deterministic project generator and Xcode test script.
- New MIT LICENSE (explicit owner choice), scientific cross-check script, expanded README, CHANGELOG, calculation methods and VALIDATION.
- `.gitignore` now also excludes `.xcresult` and TestResults; build wrapper respects an explicitly supplied DEVELOPER_DIR.
- Reference JSON/SVG and pKa/genetic-code data are unchanged. No generated screenshots/build outputs are tracked.

## Git

- Branch: `main`.
- Base commit: `691803f7ce5bfc89e7313e1ef1bdfa1968ee3d0f` (`feat: add primer and protein analysis tools`); existing history is preserved.
- Origin unchanged: `https://github.com/huangyk555-git/biochem_tool_kit.git`.
- Remote main was refreshed and matched the base commit before this source commit. Normal push is used; no rewritten history.
- This report accompanies the source commit; use Git history and the final task report for its hash and push outcome.
- Source safety audit found no credentials, private keys, local user paths, binary artifacts or build directories among version-control candidates.

## Remaining scope and handoff

- No remaining local build, calculation, UI-test, file-interaction or visual-acceptance failure.
- Secondary-structure screening is heuristic: no ΔG, mismatch/bulge model or Mg²⁺/dNTP correction.
- Modified-state pI and modification-specific chromophore effects are not modeled; native pI is labeled explicitly.
- Reference formulas remain schematic; full SVG artwork is outside this iteration.
- Optional live Codex pet binding was preserved but is not newly certified by these ten UI tests; core bridge rules remain covered by portable checks.
- No Release, tag, DMG, Developer ID signing, notarization or force push.
