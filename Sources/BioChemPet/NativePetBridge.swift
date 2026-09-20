import AppKit
import ApplicationServices
import BioChemCore
import SwiftUI

/// User-calibrated adapter: reads AX geometry and intercepts matched right clicks only.
@MainActor
final class NativePetBridge: ObservableObject {
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var status = "先授权辅助功能，再点选要连接的内置桌宠。"
    @Published private(set) var isArmed = false
    @Published private(set) var hasCandidate = false
    @Published private(set) var isBound = false
    @Published private(set) var isEnabled = false
    @Published private(set) var activationCount = 0
    @Published private(set) var ownerName = ""
    @Published private(set) var usesWindowRegion = false
    var onContextMenu: ((NSRect, NSPoint) -> Void)?
    var onCalibrationResult: (() -> Void)?

    private struct Binding {
        let element: AXUIElement
        let pid: pid_t
        let ownerID: String
        let region: PetRegionAnchor?
    }
    private var binding: Binding?
    private var candidate: Binding?
    private var candidateRect: CGRect?
    private var monitor: Any?
    private var healthTimer: Timer?
    private var armTimeout: DispatchWorkItem?
    private var outline: NSPanel?
    private var menuGate = RightClickMenuGate()
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var pressPoint: CGPoint?
    private var calibrationStart: CGPoint?
    private var calibrationDragged = false
    private var pendingMenu: DispatchWorkItem?

    init() {
        if trusted { status = "权限已就绪，请点选内置桌宠。" }
        healthTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHealth() }
        }
    }
    func shutdown() {
        clearBinding()
        healthTimer?.invalidate(); healthTimer = nil
        onContextMenu = nil; onCalibrationResult = nil
    }
    func requestPermission() {
        // Only the user's explicit button press may request the system prompt.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        trusted = AXIsProcessTrusted()
        if !trusted { status = "请在系统设置 → 隐私与安全性 → 辅助功能中开启 BioChem Bridge，然后返回这里。" }
    }
    func refreshPermission(manual: Bool = true) {
        refreshHealth()
        guard manual else { return }
        if trusted, !isBound, !isArmed, !hasCandidate {
            status = "权限已就绪。下一步：点击“开始点选桌宠”，再单击原桌宠身体。"
        } else if !trusted {
            status = "尚未识别到授权。若系统开关已开启，请重启工具；仍未生效时，在辅助功能列表移除旧条目，再添加“显示当前应用”定位的这个版本。"
        }
    }
    func revealCurrentApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
    func restartApplication() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] app, error in
            Task { @MainActor in
                if app != nil { NSApp.terminate(nil) }
                else { self?.status = "重启未完成：\(error?.localizedDescription ?? "请退出后重新打开当前应用。")" }
            }
        }
    }
    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
    func beginBinding() {
        refreshHealth()
        guard trusted else { status = "尚未获得辅助功能权限，请先完成授权。"; return }
        cancelBinding()
        stopMonitoring()
        isEnabled = false; binding = nil; isBound = false; menuGate.cancel()
        guard ensureMonitoring() else { return }
        isArmed = true
        status = "20 秒内单击内置桌宠身体。不要点聊天框、铃铛或通知。"
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isArmed else { return }
            self.cancelBinding(); self.status = "点选已超时；准备好桌宠后可重试。"
            self.onCalibrationResult?()
        }
        armTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }
    func confirmBinding() {
        guard let candidate, let rect = Self.rect(for: candidate), validOwner(candidate) else {
            cancelBinding(); status = "所选元素已变化，请重新点选。"; return
        }
        usesWindowRegion = candidate.region != nil
        binding = candidate; self.candidate = nil; candidateRect = nil
        hasCandidate = false; isBound = true; isEnabled = ensureMonitoring() && startRightClickTap()
        outline?.orderOut(nil)
        ownerName = NSRunningApplication(processIdentifier: candidate.pid)?.localizedName ?? "Codex"
        guard isEnabled else { stopMonitoring(); return }
        status = usesWindowRegion ? "已连接桌宠区域（\(Int(rect.width)) × \(Int(rect.height))）。右键框内显示工具菜单；拖动后须重新点选。" : "已连接 \(ownerName) 桌宠。右键显示工具菜单，左键与悬停不打开资料。"
    }
    func cancelBinding() {
        armTimeout?.cancel(); armTimeout = nil
        isArmed = false; hasCandidate = false; candidate = nil; candidateRect = nil
        calibrationStart = nil; outline?.orderOut(nil)
        if !isEnabled { stopMonitoring() }
    }
    func setEnabled(_ enabled: Bool) {
        pendingMenu?.cancel(); menuGate.cancel()
        guard enabled else {
            isEnabled = false; cancelBinding(); stopMonitoring()
            status = isBound ? "桥接已暂停；可以恢复，也可以重新点选。" : "桥接未启用。"
            return
        }
        guard trusted, let binding, validOwner(binding), Self.rect(for: binding) != nil else {
            invalidateBinding("原绑定不可用，请重新点选内置桌宠。")
            return
        }
        isEnabled = ensureMonitoring() && startRightClickTap()
        if isEnabled { status = "桥接已恢复。右键已绑定的桌宠可显示工具菜单。" }
        else { stopMonitoring() }
    }
    func clearBinding() {
        cancelBinding(); stopMonitoring()
        binding = nil; isBound = false; isEnabled = false; ownerName = ""; usesWindowRegion = false; pressPoint = nil
        status = "绑定已清除。"
    }
    private func refreshHealth() {
        let now = AXIsProcessTrusted()
        if now != trusted {
            trusted = now
            if now { status = "权限已就绪。下一步：点击“开始点选桌宠”，再单击原桌宠身体。" }
            else { invalidateBinding("辅助功能权限已关闭，桥接已停止。") }
        }
        if isEnabled, let binding,
           !validOwner(binding) || Self.rect(for: binding) == nil {
            invalidateBinding("桌宠元素已失效或应用已退出，请重新点选。")
        }
    }
    private func invalidateBinding(_ message: String) {
        clearBinding(); status = message
    }
    private func validOwner(_ target: Binding) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated else { return false }
        return app.bundleIdentifier == target.ownerID && PetBindingRules.ownerBundleIDs.contains(target.ownerID)
    }
    private func ensureMonitoring() -> Bool {
        if monitor != nil { return true }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        if monitor == nil { status = "鼠标事件监听未能启动，请重新打开应用后重试。" }
        return monitor != nil
    }
    private func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false); CFMachPortInvalidate(eventTap) }
        if let eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes) }
        eventTap = nil; eventSource = nil
        menuGate.cancel(); pendingMenu?.cancel(); pendingMenu = nil
    }
    private func handle(_ event: NSEvent) {
        guard trusted, let point = event.cgEvent?.location else { return }
        if isArmed {
            switch event.type {
            case .leftMouseDown:
                calibrationStart = point; calibrationDragged = false
                if !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty { calibrationStart = nil; return }
                prepareCandidate(at: point)
            case .leftMouseDragged:
                if let start = calibrationStart, hypot(point.x-start.x, point.y-start.y) > 5 { calibrationDragged = true }
            case .leftMouseUp:
                guard calibrationStart != nil else { return }
                if calibrationDragged { candidate = nil; status = "刚才是拖动，请单击桌宠身体进行绑定。"; return }
                if let candidate, let rect = Self.rect(for: candidate) {
                    candidateRect = rect; isArmed = false; hasCandidate = true
                    armTimeout?.cancel(); armTimeout = nil
                    status = candidate.region == nil ? "已识别所点选元素。请确认绿色边框仅围住桌宠身体，再确认绑定。" : "桌宠未暴露独立控件：已选中所属窗口内的小区域。请确认绿色框只覆盖桌宠身体；只在框内右键生效，拖动后须重新绑定。"
                    showOutline(rect)
                    onCalibrationResult?()
                } else {
                    isArmed = false; armTimeout?.cancel(); armTimeout = nil
                    stopMonitoring()
                    onCalibrationResult?()
                }
            default: break
            }
            return
        }
        guard isEnabled, let binding else { return }
        switch event.type {
        case .leftMouseDown:
            guard validOwner(binding), let rect = Self.rect(for: binding) else { invalidateBinding("原桌宠元素已失效，请重新点选。"); return }
            pressPoint = rect.contains(point) && Self.hitBelongs(to: binding, at: point) ? point : nil
        case .leftMouseDragged:
            if binding.region != nil, let start = pressPoint, hypot(point.x-start.x, point.y-start.y)>5 {
                invalidateBinding("桌宠发生拖动，区域绑定已暂停。请在新位置重新点选。")
            }
        case .leftMouseUp: pressPoint = nil
        default: break
        }
    }
    private func startRightClickTap() -> Bool {
        if eventTap != nil { return true }
        let types: [CGEventType] = [.rightMouseDown, .rightMouseUp, .rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let bridge = Unmanaged<NativePetBridge>.fromOpaque(info).takeUnretainedValue()
                let consumed = MainActor.assumeIsolated { bridge.handleRightClick(type, event: event) }
                return consumed ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            status = "右键菜单监听未能启动。请重新开启 BioChem Bridge 的辅助功能权限，并重启本应用后重试。"
            return false
        }
        eventTap = tap; eventSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    private func handleRightClick(_ type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            menuGate.cancel()
            pendingMenu?.cancel()
            if isEnabled, trusted, let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return false
        }
        guard isEnabled, trusted, let binding else { return false }
        let gesture: RightClickMenuGate.Event
        switch type {
        case .rightMouseDown: gesture = .down
        case .rightMouseUp: gesture = .up
        case .rightMouseDragged: gesture = .dragged
        default: return false
        }
        let point = event.location
        let modified = !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
        // Bound AX calls are limited in time. Unknown/obscured targets pass through.
        AXUIElementSetMessagingTimeout(binding.element, 0.025)
        let rect = Self.rect(for: binding)
        let matched = !modified && rect?.contains(point) == true && validOwner(binding)
            && Self.hitBelongs(to: binding, at: point)
        let result = menuGate.handle(gesture, at: point, isTarget: matched, hasModifiers: modified)
        if result == .showMenu, let rect {
            pendingMenu?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isEnabled else { return }
                self.activationCount += 1
                self.onContextMenu?(Self.appKitRect(rect), Self.appKitPoint(point))
            }
            pendingMenu = work
            // Show after consuming the release, avoiding both overlapping host menus
            // and an unmatched mouse-up delivered to the host or the new menu.
            DispatchQueue.main.async(execute: work)
        }
        return result != .passThrough
    }
    private static func appKitPoint(_ point: CGPoint) -> NSPoint {
        NSPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
    }
    private func prepareCandidate(at point: CGPoint) {
        candidate = nil
        guard let hit = Self.hit(at: point) else { status = "系统未暴露此位置的辅助功能元素，请重试。"; return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(hit, &pid) == .success,
              let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
              PetBindingRules.ownerBundleIDs.contains(id) else {
            status = "刚才点击的不是 Codex / ChatGPT，请点内置桌宠身体。"; return
        }
        var window = Self.window(of: hit)
        var node: AXUIElement? = hit
        for _ in 0..<16 {
            guard let element = node else { break }
            AXUIElementSetMessagingTimeout(element, 0.15)
            if let role = Self.attribute(element, kAXRoleAttribute) as? String {
                if ["AXTextField", "AXTextArea", "AXLink", "AXStaticText"].contains(role) {
                    status = "请选择桌宠身体，不能绑定文字、链接或输入框。"; return
                }
                if let rect = Self.rect(of: element), rect.contains(point),
                   PetBindingRules.suitable(role: role, width: rect.width, height: rect.height) {
                    candidate = Binding(element: element, pid: pid, ownerID: id, region: nil)
                    return
                }
                if role == "AXWindow" { window = element; break }
                if role == "AXApplication" { break }
            }
            node = Self.parent(of: element)
        }
        // Some native overlay surfaces expose only a window. Use an explicitly
        // confirmed small window-relative region, never an unscoped screen point.
        if let window, let frame = Self.rect(of: window), let region = PetRegionAnchor(window: frame, point: point) {
            candidate = Binding(element: window, pid: pid, ownerID: id, region: region)
            return
        }
        status = "无法读取桌宠元素或所属窗口的范围，未建立绑定。请确认桌宠已显示后重试。"
    }
    private static func hit(at point: CGPoint) -> AXUIElement? {
        var result: AXUIElement?
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.025)
        return AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &result) == .success ? result : nil
    }
    private static func hitBelongs(to binding: Binding, at point: CGPoint) -> Bool {
        guard let hit = hit(at: point) else { return false }
        AXUIElementSetMessagingTimeout(hit, 0.025)
        var pid: pid_t = 0
        guard AXUIElementGetPid(hit, &pid) == .success, pid == binding.pid else { return false }
        if binding.region != nil, let window = window(of: hit), CFEqual(window, binding.element) { return true }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.12
        var node: AXUIElement? = hit
        for _ in 0..<16 {
            guard let element = node, ProcessInfo.processInfo.systemUptime < deadline else { break }
            AXUIElementSetMessagingTimeout(element, 0.025)
            if CFEqual(element, binding.element) { return true }
            node = parent(of: element)
        }
        return false
    }
    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success ? value : nil
    }
    private static func window(of element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(element, kAXWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func rect(for binding: Binding) -> CGRect? {
        guard let windowRect = rect(of: binding.element) else { return nil }
        return binding.region?.resolve(in: windowRect) ?? (binding.region == nil ? windowRect : nil)
    }
    private static func parent(of element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(element, kAXParentAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func rect(of element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), let size = attribute(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &p), AXValueGetValue(size as! AXValue, .cgSize, &s),
              p.x.isFinite, p.y.isFinite, s.width.isFinite, s.height.isFinite, s.width > 0, s.height > 0 else { return nil }
        return CGRect(origin: p, size: s)
    }
    private static func appKitRect(_ rect: CGRect) -> NSRect {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: rect.minX, y: top-rect.maxY, width: rect.width, height: rect.height)
    }
    private func showOutline(_ rect: CGRect) {
        let panel = NSPanel(contentRect: Self.appKitRect(rect).insetBy(dx: -4, dy: -4), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.ignoresMouseEvents = true
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RoundedRectangle(cornerRadius: 12).stroke(Color.green, lineWidth: 3).padding(2))
        outline?.orderOut(nil); outline = panel; panel.orderFrontRegardless()
    }
}
