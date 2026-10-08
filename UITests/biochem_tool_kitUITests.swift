import XCTest
import AppKit
import Carbon

/// Run against the native app target in biochem_tool_kit.xcodeproj.
/// Controls use accessibility identifiers; window dragging uses element-relative coordinates.
final class biochem_tool_kitUITests: XCTestCase {
    private var app: XCUIApplication!
    private var savedClipboard: [NSPasteboardItem] = []
    private var savedInputSource: TISInputSource?
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Keep native panel automation deterministic. On macOS 27, the SCIM
        // input method can crash openAndSavePanelService during Go To Folder.
        // Restore the user's input source after every test; never alter security.
        savedInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let keyboard = TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()
        XCTAssertEqual(TISSelectInputSource(keyboard), noErr)
        savedClipboard = NSPasteboard.general.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType:type) { copy.setData(data,forType:type) } }
            return copy
        } ?? []
    }
    override func tearDownWithError() throws {
        app?.terminate()
        if let savedInputSource { TISSelectInputSource(savedInputSource) }
        NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects(savedClipboard)
    }
    private func launch(_ theme: String = "light") {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-BioChem.appearance",theme]
        app.launch()
        XCTAssertTrue(app.windows["biochem_tool_kit"].waitForExistence(timeout:10))
    }
    private func pick(_ identifier:String, _ option:String) {
        if app.state != .runningForeground { app.activate() }
        let picker = app.popUpButtons[identifier]
        XCTAssertTrue(picker.waitForExistence(timeout:5))
        if identifier != "navigation.toolPicker" && identifier != "appearance.picker" { reveal(picker) }
        picker.click()
        let item = app.menuItems[option].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout:3)); item.click()
    }
    private func navigate(_ page:String) { pick("navigation.toolPicker",page) }
    private func enter(_ id:String,_ text:String) {
        if app.state != .runningForeground { app.activate() }
        let area = app.textViews[id].firstMatch
        let field = app.textFields[id].firstMatch
        let element = area.exists ? area : field
        XCTAssertTrue(element.waitForExistence(timeout:5))
        if id != "PathTextField" && id != "saveAsNameTextField" { reveal(element) }
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType:type) { copy.setData(data,forType:type) } }
            return copy
        } ?? []
        defer { pasteboard.clearContents(); pasteboard.writeObjects(saved) }
        pasteboard.clearContents(); pasteboard.setString(text,forType:.string)
        element.click(); element.typeKey("a",modifierFlags:.command); element.typeKey("v",modifierFlags:.command)
        // Keep the pasteboard fixture alive until the editor has consumed it.
        let pasted = NSPredicate { object, _ in (object as? XCUIElement)?.value as? String == text }
        XCTAssertTrue(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:pasted,object:element)],timeout:5) == .completed,
                      "Editor did not receive input: \(id)")
        if area.exists {
            // The system input-source badge is exposed as a transient Dialog.
            // Let it disappear before XCTest attempts to handle it as an alert.
            let settled = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in self.app.dialogs.count == 0 },object:nil)
            XCTAssertEqual(XCTWaiter.wait(for:[settled],timeout:5),.completed)
        }
    }
    private func result(_ id:String) -> String {
        let element = app.staticTexts[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout:5))
        return element.value as? String ?? element.label
    }
    private func snapshot(_ name:String) {
        let attachment = XCTAttachment(screenshot:app.windows["biochem_tool_kit"].screenshot())
        attachment.name = "biochem_tool_kit-"+name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func reveal(_ element:XCUIElement) {
        let page = app.scrollViews.matching(NSPredicate(format:"identifier BEGINSWITH 'page.'")).firstMatch
        for _ in 0..<24 {
            let visible = page.frame.insetBy(dx:8,dy:20)
            let frame = element.frame
            if visible.contains(frame) && element.isHittable { return }
            page.scroll(byDeltaX:0,deltaY:frame.midY < visible.midY ? 180 : -180)
        }
        XCTAssertTrue(page.frame.insetBy(dx:8,dy:20).contains(element.frame) && element.isHittable,"Control must be fully reachable by scrolling")
    }
    private func copied(_ id:String) -> String {
        let button = app.buttons[id]
        reveal(button)
        NSPasteboard.general.clearContents()
        button.click()
        let expectation = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in NSPasteboard.general.string(forType:.string) != nil },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[expectation],timeout:3),.completed)
        return NSPasteboard.general.string(forType:.string) ?? ""
    }
    func testClipboardFlows() {
        launch(); navigate("Primer Analyzer")
        enter("primer.sequenceInput","ATGCCGTA")
        XCTAssertEqual(copied("copy.Copy sequence"),"ATGCCGTA")
        XCTAssertEqual(copied("copy.Copy reverse complement"),"TACGGCAT")
        let summary = copied("copy.Copy summary")
        XCTAssertTrue(summary.contains("Estimated Tm: 24.0")); XCTAssertTrue(summary.contains("Wallace"))
        navigate("Protein Analyzer"); enter("protein.sequenceInput","AG")
        let protein = copied("copy.Copy result")
        XCTAssertTrue(protein.contains("Length: 2 aa")); XCTAssertTrue(protein.contains("146.14")); XCTAssertTrue(protein.contains("Bjellqvist"))
        navigate("Translation"); enter("translation.sequenceInput","ATGGCTTAA")
        XCTAssertEqual(copied("copy.Translated sequence · N → C"),"MA")
        navigate("FASTA Analyzer"); enter("batch.fastaInput",">中文,样本\nATGC")
        app.buttons["batch.analyze"].click()
        expectation(for:NSPredicate(format:"value CONTAINS '1 records'"),evaluatedWith:app.staticTexts["batch.count"])
        waitForExpectations(timeout:10)
        let batch = copied("copy.Copy batch result")
        XCTAssertTrue(batch.contains("\"中文,样本\"")); XCTAssertTrue(batch.contains("50"))
    }
    func testLaunchAndNavigation() {
        launch()
        navigate("Primer Analyzer"); enter("primer.sequenceInput","ATGCCGTA")
        for page in ["Reference · 氨基酸 / 官能团","Primer Analyzer","Primer Pair","DNA Tools","Translation","Protein Analyzer","Protein Options","FASTA Analyzer","Dilution","Molarity / Mass"] {
            navigate(page); XCTAssertTrue(app.popUpButtons["navigation.toolPicker"].exists)
        }
        navigate("Primer Analyzer")
        XCTAssertEqual(app.textViews["primer.sequenceInput"].value as? String,"ATGCCGTA")
        XCTAssertEqual(result("primer.lengthResult"),"8 nt")
    }
    func testPrimerNearestNeighborAndSalt() {
        launch(); navigate("Primer Analyzer")
        enter("primer.sequenceInput","CGTTCCAAAGATGTGGGCATGAGCTTAC")
        XCTAssertTrue(result("primer.lengthResult").contains("28"))
        XCTAssertTrue(result("primer.gcResult").contains("%"))
        pick("primer.methodPicker","Nearest Neighbor")
        let before = result("primer.tmResult")
        reveal(app.buttons["primer.advanced"]); app.buttons["primer.advanced"].click()
        enter("primer.saltInput","100")
        XCTAssertNotEqual(before,result("primer.tmResult"))
        snapshot("Primer-Advanced")
    }
    func testPrimerPairAndSecondaryStructure() {
        launch(); navigate("Primer Pair")
        enter("pair.forwardInput","AAAACCCCGGGGTTTT")
        enter("pair.reverseInput","AAAACCCCGGGGTTTT")
        XCTAssertTrue(result("pair.deltaTm").contains("0"))
        XCTAssertTrue(app.descendants(matching:.any)["structure.Hetero-dimer"].firstMatch.exists)
        snapshot("Primer-Pair")
    }
    func testProteinDisulfidesAndModifications() {
        launch(); navigate("Protein Options")
        enter("protein.sequenceInput","MACKSTYWCCC")
        let before = result("protein.mwResult")
        XCTAssertFalse(result("protein.piResult").isEmpty)
        pick("protein.disulfidePicker","Maximum possible disulfides")
        XCTAssertNotEqual(before,result("protein.mwResult"))
        pick("protein.nTermPicker","Acetylation")
        XCTAssertNotEqual(before,result("protein.mwResult"))
        snapshot("Protein-Modifications")
        app.scrollViews.matching(NSPredicate(format:"identifier BEGINSWITH 'page.'")).firstMatch.scroll(byDeltaX:0,deltaY:-420)
        snapshot("Protein-Modified-Results")
    }
    func testBatchAndCalculators() {
        launch(); navigate("FASTA Analyzer")
        enter("batch.fastaInput",">one\nATGC\n>two\nGGCC\n>bad\nATGN")
        app.buttons["batch.analyze"].click()
        let count = app.staticTexts["batch.count"]
        expectation(for:NSPredicate(format:"value CONTAINS '3 records'"),evaluatedWith:count)
        waitForExpectations(timeout:10)
        XCTAssertTrue((count.value as? String ?? count.label).contains("1 errors"))
        snapshot("Batch-FASTA")
        app.scrollViews["batch.resultTable"].scroll(byDeltaX:-500,deltaY:0)
        snapshot("Batch-Error-Column")
        navigate("Dilution"); XCTAssertTrue(result("calculator.dilutionResult").contains("10"))
        navigate("Molarity / Mass")
        enter("calculator.mwInput","58.44"); enter("calculator.concentrationInput","100"); enter("calculator.volumeInput","10")
        XCTAssertTrue(result("calculator.massResult").contains("58.44"))
        snapshot("Calculators")
    }
    private func goToPath(_ path:String) {
        app.typeKey("g",modifierFlags:[.command,.shift])
        enter("PathTextField",path)
        app.typeKey(.return,modifierFlags:[])
    }
    private func confirmFilePanel() {
        let button = app.buttons["OKButton"]
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            button.exists && button.isEnabled && button.isHittable
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:10),.completed)
        button.click()
    }
    func testNativeFileOpenAndExport() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("biochem-ui-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:folder) }
        launch(); navigate("FASTA Analyzer")
        for ext in ["fasta","fa","faa","fna"] {
            let content = ">中文,"+ext+"\nATGC\n>second\nGGCC\n"
            let file = folder.appendingPathComponent("input."+ext)
            try content.write(to:file,atomically:true,encoding:.utf8)
            if app.state != .runningForeground { app.activate() }; app.buttons["batch.open"].click()
            XCTAssertTrue(app.buttons["OKButton"].waitForExistence(timeout:5))
            goToPath(file.path)
            // Wait for navigation to settle before confirming the selected file.
            confirmFilePanel()
            let loaded = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@",content),object:app.textViews["batch.fastaInput"])
            XCTAssertEqual(XCTWaiter.wait(for:[loaded],timeout:5),.completed)
            app.buttons["batch.analyze"].click()
            expectation(for:NSPredicate(format:"value == '2 records · 0 errors'"),evaluatedWith:app.staticTexts["batch.count"])
            waitForExpectations(timeout:10)
        }
        for format in ["CSV","TSV","FASTA"] {
            pick("batch.formatPicker",format)
            let expected = copied("copy.Copy batch result")
            XCTAssertFalse(expected.isEmpty)
            app.buttons["batch.save"].click()
            let saveName = app.textFields["saveAsNameTextField"]
            XCTAssertTrue(saveName.waitForExistence(timeout:5))
            enter("saveAsNameTextField","export."+format.lowercased())
            goToPath(folder.path)
            confirmFilePanel()
            let output = folder.appendingPathComponent("export."+format.lowercased())
            let written = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in FileManager.default.fileExists(atPath:output.path) },object:nil)
            XCTAssertEqual(XCTWaiter.wait(for:[written],timeout:5),.completed)
            let content = try String(contentsOf:output,encoding:.utf8)
            XCTAssertEqual(content,expected)
            XCTAssertTrue(content.contains("中文,fna"))
            if format == "CSV" { XCTAssertTrue(content.contains("\"中文,fna\"")) }
            if format == "TSV" { XCTAssertTrue(content.contains("Name\tLength")) }
            if format == "FASTA" { XCTAssertEqual(content,">中文,fna\nATGC\n>second\nGGCC\n") }
        }
        snapshot("Native-File-Open-Export")
    }
    func testNativeFileDrop() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("biochem-drop-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:folder) }
        let file = folder.appendingPathComponent("drop-test.fasta")
        let content = ">dragged 中文\nATGCCGTA\n"
        try content.write(to:file,atomically:true,encoding:.utf8)
        launch(); navigate("FASTA Analyzer")
        let target = app.textViews["batch.fastaInput"]
        let targetFrame = target.frame
        NSWorkspace.shared.activateFileViewerSelecting([file])
        let finder = XCUIApplication(bundleIdentifier:"com.apple.finder")
        let window = finder.windows[folder.lastPathComponent]
        XCTAssertTrue(window.waitForExistence(timeout:10))
        // Finder can activate a different existing window. Raise this fixture
        // through the Window menu before synthesizing any pointer operation.
        finder.activate()
        let windowMenu = finder.menuBarItems["Window"].exists
            ? finder.menuBarItems["Window"] : finder.menuBarItems["窗口"]
        XCTAssertTrue(windowMenu.waitForExistence(timeout:5))
        windowMenu.click()
        let fixtureWindow = finder.menuItems[folder.lastPathComponent].firstMatch
        XCTAssertTrue(fixtureWindow.waitForExistence(timeout:5))
        fixtureWindow.click()
        addTeardownBlock { if window.exists { finder.activate(); window.typeKey("w",modifierFlags:.command) } }
        // Expose the app editor above Finder without fixed screen coordinates.
        let title = window.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.02))
        let distance = max(0,targetFrame.maxY-window.frame.minY+40)
        title.click(forDuration:0.2,thenDragTo:title.withOffset(CGVector(dx:0,dy:distance)))
        let source = window.descendants(matching:.any).matching(NSPredicate(format:"(label == %@ OR value == %@) AND elementType != %d",file.lastPathComponent,file.lastPathComponent,XCUIElement.ElementType.window.rawValue)).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout:5))
        // Only query Finder while it is frontmost. Capture the app destination
        // before opening Finder so cross-app accessibility cannot change focus.
        source.click()
        XCTAssertTrue(source.isHittable)
        let destination = window.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(
            dx:targetFrame.midX-window.frame.minX,dy:targetFrame.midY-window.frame.minY))
        source.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            .click(forDuration:0.1,thenDragTo:destination,withVelocity:.slow,thenHoldForDuration:2)
        if app.state != .runningForeground { app.activate() }
        let loaded = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@",content),object:target)
        XCTAssertEqual(XCTWaiter.wait(for:[loaded],timeout:10),.completed)
        app.buttons["batch.analyze"].click()
        expectation(for:NSPredicate(format:"value == '1 records · 0 errors'"),evaluatedWith:app.staticTexts["batch.count"])
        waitForExpectations(timeout:10)
        snapshot("Native-File-Drop")
    }
    func testLightRegression() { regression("light") }
    func testDarkRegression() { regression("dark") }
    private func regression(_ theme:String) {
        launch(theme); snapshot(theme+"-Main")
        navigate("Primer Analyzer"); snapshot(theme+"-Primer-Empty")
        enter("primer.sequenceInput","ATGN"); snapshot(theme+"-Primer-Error")
        enter("primer.sequenceInput","CGTTCCAAAGATGTGGGCATGAGCTTAC"); snapshot(theme+"-Primer")
        app.buttons["primer.advanced"].click(); snapshot(theme+"-Primer-Advanced")
        enter("primer.saltInput","bad"); snapshot(theme+"-Numeric-Error")
        enter("primer.saltInput","50"); enter("primer.sequenceInput",String(repeating:"ATGC",count:60)); snapshot(theme+"-Primer-Long")
        navigate("Primer Pair"); enter("pair.forwardInput","GCGCGCAAAAGCGCGC"); enter("pair.reverseInput","GCGCGCGCGCGCGCGC"); snapshot(theme+"-Primer-Pair")
        navigate("DNA Tools"); enter("dna.sequenceInput",">DNA\nATGCATGC"); snapshot(theme+"-DNA")
        navigate("Protein Analyzer"); snapshot(theme+"-Protein-Empty")
        enter("protein.sequenceInput","AX"); snapshot(theme+"-Protein-Error")
        enter("protein.sequenceInput",">protein\nMACKSTYWCCC"); snapshot(theme+"-Protein")
        navigate("Protein Options"); snapshot(theme+"-Protein-Modifications")
        enter("protein.sequenceInput",String(repeating:"ACDEFGHIKLMNPQRSTVWY",count:100)); snapshot(theme+"-Protein-Long")
        navigate("FASTA Analyzer"); snapshot(theme+"-Batch-Empty")
        enter("batch.fastaInput","missing header"); app.buttons["batch.analyze"].click()
        XCTAssertTrue(app.staticTexts["batch.error"].waitForExistence(timeout:5)); snapshot(theme+"-Batch-Error")
        let records = (1...40).map { ">中文长标题-\($0)-"+String(repeating:"header",count:15)+"\nATGCATGC" }.joined(separator:"\n")
        enter("batch.fastaInput",records); app.buttons["batch.analyze"].click()
        expectation(for:NSPredicate(format:"value CONTAINS '40 records'"),evaluatedWith:app.staticTexts["batch.count"])
        waitForExpectations(timeout:10); snapshot(theme+"-Batch-FASTA")
        app.scrollViews.firstMatch.scroll(byDeltaX:0,deltaY:-500); snapshot(theme+"-Batch-Scrolled")
        navigate("Dilution"); snapshot(theme+"-Calculators")
    }
}
