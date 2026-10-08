# biochem_tool_kit — validation status

Date: 2026-10-08. Final local build/test/visual acceptance passed; source and staged safety are checked before the source commit.

## Environment

- Xcode 27.0 (27A266a), `/Applications/Xcode.app/Contents/Developer`.
- macOS 27.0 (26A428), arm64. App minimum macOS 13; native test targets minimum macOS 14 for the current XCTest framework.
- Branch `main`; base commit `691803f7ce5bfc89e7313e1ef1bdfa1968ee3d0f`.
- Origin unchanged: `https://github.com/huangyk555-git/biochem_tool_kit.git`.
- System Documents and XCTest automation prompts were approved normally. No security mechanism disabled.

## Actual results

| Check | Result |
| --- | --- |
| Native Debug | PASS in current complete run |
| Native Release | PASS, arm64 |
| XCTest | 35 executed, 35 passed, 0 failed |
| XCUITest | 10 executed, 10 passed, 0 failed in one complete run |
| Portable regression | 112 passed, 0 failed in Debug and Release |
| Scientific comparison | 60 passed, Biopython 1.85 |
| Light / Dark visual review | PASS: 47 final app captures inspected, including empty/error/long states, scrolling, modified results and file drop |
| Native file open | PASS: .fasta, .fa, .faa, .fna |
| Finder drag/drop | PASS in final complete run; fixture window explicitly selected |
| Native export | PASS: CSV, TSV, FASTA; exact UTF-8 contents read back |
| Clipboard | PASS: primer, reverse complement, summary, protein, translation, batch |
| Source safety | 65 source candidates scanned; no secret, private-key, user-path or build-artifact findings; 51 staged files also audited with no findings |
| Local acceptance | PASS; Git commit/push outcome is reported separately |

## Actual fixes

- Distinct native app target avoids collision with the Swift Package executable; architecture selection is consistent for app/package targets.
- The Xcode script builds an exact source snapshot in a temporary workspace and preserves genuine results, including failures, in ignored `work/`.
- Retained native tab pages replace overlapping hidden editors, preserving state while keeping inactive editors out of the visible view hierarchy.
- Native sequence editor supports real text input, accessibility value notifications and file drops. Updated result accessibility values track recalculation.
- Advanced settings expand reliably; copy identifiers remain stable; batch export includes copy; long labels and results wrap.
- Test helpers verify actual pasted values, scroll interactive controls, read static results without requiring hit testing, and resolve Finder drag endpoints relative to its window.
- Finder tests raise their exact fixture window through the native Window menu before any pointer operation; target geometry is captured before switching apps.
- File-panel confirmation waits for an enabled, hittable native OK button and clicks it; directory navigation could outlast two consecutive Return events.
- Native open/save panels are attached to the app window and tested through their actual user interface.

## System file-panel crash diagnosis

A failed TSV save produced a crash attachment for Apple's `com.apple.appkit.xpc.openAndSavePanelService`: EXC_BREAKPOINT/SIGTRAP in AppKit text-input handling with an SCIM input-method thread. The main application remained running. All four opens and CSV export had already passed in that run. This explains the observed panel disappearing and cancel callback; it is not a serialization failure.

Tests now temporarily select an ASCII-capable keyboard and restore the original input source after each test. The complete native open/CSV/TSV/FASTA scenario subsequently passed. This is a test-environment workaround, not a macOS fix or certification of Chinese-input-method compatibility on this OS build. Clipboard contents are also restored. No permissions, sandbox, Gatekeeper or other security controls are bypassed.

The historical tool-specific `Sky Computer Use native pipe closed before response` error was not independently reproduced. Earlier thread samples showed an idle app, and actual permission dialogs explained earlier blocked runs. Do not equate that old transport error with a proven application crash.

## Local evidence — ignored, never uploaded

- `work/xcode-validation.NcO3Ro/Tests.xcresult`: successful final complete test run.
- `work/accepted-captures-20261008/`: 47 final app screenshots and review sheets.

- `work/validation-final-20261008.log`: final Debug, 35 unit/10 UI passes, and Release.
- `work/validation-20261008.log`: preceding 9/10 UI run; native confirmation race diagnosed from recording.
- `work/file-confirm-20261008.log`: native confirm-button fix passed all open/export checks.
- `work/drop-menu-20261008.log`: native Finder menu selection and full drop scenario passed.
- `work/checks-20261008.log`, `work/scientific-comparison-20261008.log`: 112 checks and 60 comparisons passed.
- `work/validation-final-20260923.log`: preceding complete run, 35 unit passes and 9/10 UI passes.
- `work/drop-stability-clean.log`: three consecutive complete Finder-drop passes.
- `work/final-captures-1/`: 44 inspected app screenshots including wrapping fix.
- `work/ui-files-ascii.log` and `.xcresult`: complete native file scenario passed.
- `work/ui-files-events.xcresult`: actual system crash attachment and preceding successful open/CSV steps.
- `work/ui-interaction-final.log`: clipboard, Finder drop, protein options and calculators passed; earlier native file attempt failed.
- `work/validation-captures-20260923/`: 41 inspected earlier app captures and contact sheets.
- `work/final-checks-debug-20260923.log`, `work/final-checks-release.log`: 112 checks each.
- `work/final-scientific-comparison-20260923.log`: 60 independent comparisons.
- `work/source-safety-20260923.json`: prior source audit.

Full-desktop recordings and crash reports may contain local host information; they remain ignored. No Release, tag, DMG, Developer ID signing, notarization or force push. Optional live Codex pet binding is preserved, but these ten UI tests do not newly certify third-party desktop integration.

Final warnings: Xcode reports skipped App Intents metadata extraction because this app does not use AppIntents; no source compiler warning or build error remains in the successful final run. No tests were removed, skipped or weakened.
