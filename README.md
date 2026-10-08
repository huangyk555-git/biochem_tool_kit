# biochem_tool_kit

Native macOS biochemical / molecular biology toolkit, built with Swift, SwiftUI and AppKit. Offline reference data and pure Swift calculators; optional right-click bridge to an existing Codex desktop pet.

**Source-only, local development iteration.** No DMG, GitHub Release, Developer ID signing or notarization. Current work targets 0.6.0 (Unreleased). The complete Xcode build/test and visual gates **passed on 2026-10-08**; see [Validation](VALIDATION.md).

## Features

- Reference: 20 standard amino acids, 24 functional groups, multilingual search.
- DNA & Primer: Primer Analyzer, Primer Pair, DNA Tools, Translation.
- Protein: Protein Analyzer, Protein Options / Modifications.
- Batch: multi-FASTA analysis, file opening / dropping, CSV / TSV / FASTA export.
- Calculators: dilution and molarity / mass with typed unit conversion.
- Native grouped menus, copyable results, system / light / dark appearance. Sequence input stays in memory; saved files and clipboard copies are explicit user actions.

**Tm, pI, MW, extinction coefficients and secondary-structure risk are theoretical / estimated values.** This tool supports quick biochemical / molecular biology calculations, laboratory preparation and sequence inspection; it does not replace professional experimental-design software or experimental measurements.

## Screenshots

The current main reference window and navigation were visually inspected. The native UI test source captures Main, Primer, Advanced, Primer Pair, Protein, Modifications, Batch and Calculators in Light/Dark with `XCTAttachment`. Full Xcode 27.0 is now available. UI execution began but was interrupted by other foreground windows; the complete regression screenshot set has **not** been approved. Testing has resumed and is currently waiting for the macOS “XCTest — Enable UI Automation” Touch ID/password verification (Documents access is approved). No mock screenshot is presented as a test result. After running the Xcode suite, review attachments in `work/xcode-validation.*/Tests.xcresult` before declaring UI acceptance.

## Reference Tools

20 standard amino acids retain Chinese/English names, one/three-letter codes, side chains, typical side-chain charge at pH 7 and categories. 24 functional groups retain bilingual names, formulas, descriptions and references. JSON stays separate from views. Structural formulas are shown as text, with existing aldehyde/ketone/amide SVG examples; complete drawn SVGs for all amino acids remain future work. Search supports names, codes, aliases and multiple terms. The charge convention is side-chain predominant charge, not whole-molecule net charge.

## Primer Analyzer

Standard mode accepts A/T/G/C only; whitespace is removed and ASCII lowercase becomes uppercase. Unsupported characters are reported, never silently removed. Outputs: sequence, length, A/T/G/C counts, GC/AT%, estimated unmodified ssDNA mass, reverse, antiparallel complement and reverse complement. Copy sequence, reverse complement and summary are available.

Methods: Auto, Wallace (Simple estimate), Basic empirical GC/Na⁺, Nearest Neighbor. The actual method is always displayed. Auto uses Wallace below 14 nt and NN otherwise. Basic requires ≥14 nt; NN is scoped to 2–200 nt. Extreme short-sequence NN predictions remain theoretical and should not be interpreted as PCR recommendations.

## Nearest-Neighbor Tm

Uses SantaLucia's 1998 unified DNA/DNA parameters (Table 2), terminal initiation and symmetry corrections, plus the monovalent salt **entropy** correction. Advanced Settings accepts primer concentration in nM/μM and salt in mM. Concentration means each strand of an equimolar non-self-complementary duplex; for a self-complementary oligo, it means the total concentration of that single species. No Mg²⁺, dNTP, mismatches, dangling ends or additives correction is implemented. See [Calculation Methods](docs/CALCULATIONS.md).

Primer Pair reports both lengths, GC%, Tm and actual methods, ΔTm, and a heuristic annealing range (lower Tm minus 5 to minus 3 °C). This is an **Estimated recommendation**; mixed Auto methods are flagged and should be replaced by one common method for comparison.

## Hairpin / Dimer Analysis

Hairpin, self-dimer and hetero-dimer screening reports contiguous complementary length, GC pairs, loop size where relevant, 3′ complementarity, alignment and Low/Moderate/High risk. Maximum 200 nt per primer. Rules are explicit in the service and UI; they are not calibrated probabilities. Only ungapped Watson–Crick pairing is considered. **No ΔG is calculated.** The shown alignment is the longest candidate; the global 3′ warning can come from another candidate. This is not a substitute for a folding/thermodynamic engine.

## DNA Tools

Raw DNA or one FASTA record: length, counts, GC%, reverse, complement and reverse complement, with copy. Ambiguous IUPAC bases and RNA U are not supported. Complement is displayed aligned 3′→5′; reverse complement is 5′→3′.

## Translation

NCBI standard code (table 1), frames +1/+2/+3. Stop at the first stop excludes `*` and following codons; translate-through retains `*`. Incomplete trailing codons are excluded and counted. No ORF prediction or alternate genetic code.

## Protein Analyzer

Raw sequence or one FASTA record, 20 standard amino acids only. Reports length, native theoretical MW in Da/kDa, Bjellqvist theoretical pI, composition, acidic/basic/aromatic counts, Trp/Tyr/Cys, average residue mass and estimated ε₂₈₀. Ambiguous residues, gaps and stop symbols are rejected. Different pKa datasets can yield slightly different theoretical pI values in different software.

## Protein Modifications

N-terminal Native / Met removed / Acetylation; C-terminal Native / Amidation. Explicit residue-position modifications: phosphorylation (S/T/Y), oxidation (M), methylation (K/R), acetylation (K). This deliberately limited site set is documented, not a full proteomics engine. Average mass shifts are from Unimod, consistent with the protein average-mass convention. Original sequence is retained; positions are 1-based in that original sequence. Invalid, removed or duplicate sites are rejected.

Display: Base MW, Modification ΔMass (including terminal and disulfide changes), Final theoretical MW. **pI/composition remain explicitly the original unmodified sequence's values.** Modified-residue pKa prediction is not implemented. N-Met removal and N-acetylation are mutually exclusive in this simple model.

## Disulfide Options

Default Reduced; optional Custom (0…floor(Cys/2)) or Maximum possible. Each S–S bond subtracts 2.01588 Da and adds 125 M⁻¹ cm⁻¹ to the reduced ε₂₈₀ estimate. Excess counts are blocked. This does not infer real connectivity. Standard Trp/Tyr absorptivities are retained; modification-induced chromophore changes are not modeled.

## Batch FASTA

Paste multi-FASTA, open a local UTF-8 file, or drop `.fasta`, `.fa`, `.faa`, `.fna`. Parsing and analysis run away from the main thread with one result update. Maximum 10 MB / 10,000 records; each sequence ≤100,000 bases/residues. Errors are per-record; good records still produce results. Duplicate headers retain unique record IDs. Tables show metrics, not full sequences. Batch protein uses native/reduced conditions and does not inherit single-protein options.

## Export

Native `NSSavePanel`; no hard-coded output path. UTF-8 CSV/TSV have headers, correctly quoted delimiters, quotes, newlines and Unicode; they include an Error column. FASTA exports only valid records and wraps sequence lines at 80 characters. No modifications are encoded in exported FASTA. Long table fields have a tooltip; export retains full text.

## Solution Calculators

Dilution solves any one unknown in C1V1=C2V2. Molarity / Mass computes required mass from MW, target concentration and final volume. Supports M/mM/μM/nM, L/mL/μL and g/mg/μg. Internal units are mol/L, L and g. Rejects nonfinite inputs, overflow/underflow and non-dilution conditions. Final volume is total volume; use the actual salt/hydrate MW. Purity defaults to 100%.

## Calculation Methods

The full [methods, parameter tables and references](docs/CALCULATIONS.md) cover Tm, NN salt/concentration terms, residue masses, pKa, extinction, modification shifts, disulfides and screening rules. No third-party source implementation was copied. The optional development cross-check uses an independently installed Biopython; the application has no Python/Biopython runtime dependency.

## Testing

- `BioChemCheck`: 112 portable regression checks, including the same calculation cases invoked by XCTest.
- Existing XCTest target reused: `BioChemCoreTests`, 35 test methods.
- New native XCUITest target: `biochem_tool_kitUITests`, 7 original test methods covering navigation, core flows and Light/Dark screenshot matrices, plus 3 clipboard/native-file/drop methods.
- Deterministic inputs: `Tests/Support/TestFixtures.swift` and fixed UI fixtures; no random sequences.
- Current status: native Debug/Release builds, all 35 XCTest methods, 112 portable checks and 60 independent Biopython 1.85 comparisons pass. All 10 XCUITest methods passed in one complete run; Light/Dark screenshots were inspected, including empty/error/long states, horizontal scrolling and modified results. Native open/save, Finder drop and all six clipboard flows have passed. No test is skipped or disabled to claim success.

With a complete initialized Xcode, open `biochem_tool_kit.xcodeproj`, select the shared `biochem_tool_kit` scheme, and use **Command+U**. The native app target is `biochem_tool_kit`; its distinct name prevents confusion with the package executable `BioChemPet`. Or run:

```sh
./scripts/test-xcode.sh
```

For a non-default Xcode location, set `DEVELOPER_DIR` to that installation's `Contents/Developer` for the command. The script does not change global `xcode-select`, accept licenses, weaken security settings, or install Xcode. It builds Debug, runs all unit/UI tests with screenshot attachments, then builds Release, consistently using the current Mac architecture. Universal distribution validation is separate. UI tests temporarily select an ASCII-capable keyboard and restore the original input source afterward: macOS 27 SCIM can crash the system file-panel service during automated Go To Folder input. Keep the desktop available and avoid switching apps during UI tests. A graphical logged-in session and normal Xcode automation permissions are required for UI testing. Review screenshots for clipping, contrast, overflow and scrolling; attachments alone do not establish visual correctness.

## Build from Source

macOS 13+, Swift 5.9+ (compatible Xcode or Command Line Tools), Python 3 for the existing build wrapper. Native runtime requires no Python, Node, Homebrew or external package. The native test targets require macOS 14+ with the current Xcode XCTest framework; the app deployment target remains macOS 13.

```sh
./scripts/swift-local.sh build
./scripts/swift-local.sh run BioChemCheck
./scripts/build-app.sh
open outputs/biochem_tool_kit.app
```

The wrapper keeps caches local and overlays duplicate legacy CLT module interfaces without modifying system tools. The local app uses ad-hoc signing only. Bundle ID remains `local.biochem.bridge`. `Config/Info.plist` is shared by the native Xcode target and packaging script. Internal Swift modules/targets (`BioChemCore`, `BioChemUI`, `BioChemPet`) and preference keys remain stable; they are not user-visible product names. Existing old local app copies are not deleted automatically.

Optional scientific audit with an already-installed Biopython:

```sh
./scripts/swift-local.sh run BioChemCheck --scientific-json > work/scientific.json
python3 scripts/scientific-crosscheck.py work/scientific.json
```

## Project Structure

- `Sources/BioChemCore`: Reference JSON/SVG, `Models`, `Data`, `Services`, pet event/binding rules.
- `Sources/BioChemUI`: existing reference panel, grouped navigation and native `Modules` pages.
- `Sources/BioChemPet`: app lifecycle, About/settings/menus, optional pet bridge.
- `Tests/BioChemCoreTests`: existing and new XCTest wrappers.
- `Tests/Support`: shared checks, fixed fixtures and scientific audit data output.
- `UITests`: native UI flows and retained screenshot attachments.
- `biochem_tool_kit.xcodeproj`: app, unit/UI test targets and shared scheme; generated deterministically by `scripts/generate-xcode-project.py` (no external generator dependency).
- `Config/Info.plist`, `scripts`, `docs`, `VALIDATION.md`, `CHANGELOG.md`.

## Roadmap

1. Maintain complete Xcode unit/UI regression and scientific fixtures with future changes.
2. Calibrated secondary-structure thermodynamics, mismatch/loop support and Mg²⁺/dNTP correction.
3. Modification-aware pI / chromophore effects, optional additional mass conventions.
4. Complete reference structure artwork and additional scientific fixtures.
5. Formal macOS distribution as a separate future phase, after test acceptance.

## License

Project source is under the [MIT License](LICENSE), selected by the repository owner. Scientific parameter provenance is listed in the methods document.

## 可选：连接 Codex 桌宠

1. 在设置中开启“连接 Codex 桌宠”（首次默认关闭，保存开关状态）。
2. 仅此功能需要辅助功能权限。在 **系统设置 → 隐私与安全性 → 辅助功能** 中开启当前应用。已有授权时可直接点选。
3. 在 Codex 中唤醒桌宠，点击“开始点选桌宠”，20 秒内单击桌宠身体。
4. 确认绿色边框只围住桌宠，然后点击“确认绑定”。没有独立控件时使用明确确认过的窗口内小区域。
5. 此后**右键桌宠 → 打开 biochem_tool_kit**，或从 Reference / DNA & Primer / Protein / Batch / Calculators 二级菜单直接进入工具。菜单中“关闭资料窗口”只收起资料；“退出 biochem_tool_kit”关闭整个应用并停止连接。左键保留原有动作，悬停不触发；Option + 右键保留原菜单。

关闭“连接 Codex 桌宠”会停止事件监听、取消点选计时器、清除绑定并释放连接模块；生化查询继续使用。关闭设置窗口不会断开连接。“启用右键菜单”可临时暂停已绑定的菜单；总开关关闭则彻底断开。

开关状态会保留，但桌宠绑定只保存在内存中。重启应用、重新开启连接或区域模式下拖动后，须重新点选。即使保存为开启，应用启动时仍优先显示资料库，不会自动弹出授权框或点选窗口。

**已授权但点选按钮仍为灰色：** 点击“刷新权限”，必要时“重启工具”。若旧授权因更新失效，在系统辅助功能列表移除旧条目，再通过“显示当前应用”定位当前版本并重新添加。应用显示名称与新包路径统一为 `biochem_tool_kit`；Bundle ID 保持 `local.biochem.bridge`。更换包路径或本地构建更新后，辅助功能授权可能需要重新添加。

**兼容性边界：** 这不是官方桌宠插件。菜单由独立桥接程序显示，并非向 Codex 原生菜单插入选项。桥接只读取辅助功能几何信息，不修改客户端或宠物文件；启用后拦截命中已确认桌宠的无修饰键右键序列，避免同时弹出两套菜单。菜单在右键松开后显示；右键拖动、移出目标或加修饰键会取消弹出。其他位置和带 Option 的右键不拦截。若无法建立事件监听，会显示失败原因，不会假装已启用。若没有合适的小型辅助功能元素，但能识别所属窗口，使用用户明确确认过的窗口内小区域。它验证同一窗口、进程和命中关系，并在窗口改尺寸或从绑定区域拖动时失效；不会把整个窗口或任意屏幕坐标作为目标。若连所属窗口范围也不可读，则拒绝绑定。

## 权限与数据

辅助功能权限只用于识别点选元素的进程、类型、父级关系和几何位置。桥接程序不读取 AXValue、聊天文本或剪贴板，不监听键盘，不模拟点击，不申请屏幕录制权限，不上传数据。左键监听仅用于首次点选与区域拖动失效判定；右键事件监听仅在确认绑定并启用后启动。暂停或权限撤销时停止监听，没有鼠标悬停监听。

点选只接受 `com.openai.codex` 或 `com.openai.chat` 进程。确认前会描绘识别范围；绑定后会再次验证点击所属进程与元素关系，拒绝被其他窗口覆盖的点击。只凭大小不能判断一个元素就是桌宠，因此首次人工确认十分必要。区域模式不能自动跟随宠物在同一窗口内部的布局变化；移动、换宠物或布局改变后必须重新点选。
