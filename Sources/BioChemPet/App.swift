import AppKit
import SwiftUI
import BioChemCore
import BioChemUI

@main
struct BioChemPetApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var library: BioChemPanelController?
    private let connection = PetConnectionOptions()
    private var bridge: NativePetBridge? { connection.bridge }
    private var settings: NSPanel?
    private var statusItem: NSStatusItem?
    private var menuAnchor: NSRect?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            library = try BioChemPanelController(floating: false, onOpenSettings: { [weak self] in self?.showSettings() })
            connection.configureBridge = { [weak self] bridge in
                bridge.onContextMenu = { [weak self] anchor, point in self?.showPetMenu(near: anchor, at: point) }
                bridge.onCalibrationResult = { [weak self] in self?.showSettings() }
            }
            connection.restorePreference()
            installMenu()
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 730), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "BioChem · 设置"
            panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
            panel.contentView = NSHostingView(rootView: AppSettingsView(connection: connection,
                onBind: { [weak self] in
                    guard let self, let bridge = self.bridge else { return }
                    bridge.beginBinding()
                    if bridge.isArmed { self.library?.hide(); self.settings?.orderOut(nil) }
                },
                onOpenLibrary: { [weak self] in self?.settings?.orderOut(nil); self?.library?.show() },
                onPreviewMenu: { [weak self] in self?.showMenuPreview() }))
            panel.center(); settings = panel
            library?.show()
        } catch {
            let alert = NSAlert()
            alert.messageText = "生化资料库未能载入"; alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { library?.show(); return true }
    func applicationWillTerminate(_ notification: Notification) { bridge?.shutdown() }
    func applicationDidBecomeActive(_ notification: Notification) { bridge?.refreshPermission(manual: false) }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let value = NSMenuItem(title: title, action: action, keyEquivalent: key)
        value.target = self; return value
    }
    private func installMenu() {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "atom", accessibilityDescription: "BioChem 生化速查")
        status.button?.toolTip = "BioChem · 生化速查"
        let menu = NSMenu()
        menu.addItem(item("打开生化资料", #selector(openLibrary)))
        addToolMenus(to: menu)
        menu.addItem(.separator())
        menu.addItem(item("设置 · 可选桌宠连接…", #selector(openSettings)))
        menu.addItem(item("退出 BioChem", #selector(quit), key: "q"))
        status.menu = menu; statusItem = status
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(item("设置…", #selector(openSettings), key: ","))
        appMenu.addItem(item("打开生化资料", #selector(openLibrary), key: "o"))
        appMenu.addItem(item("关闭窗口", #selector(closeWindow), key: "w"))
        appMenu.addItem(item("退出 BioChem", #selector(quit), key: "q"))
        appItem.submenu = appMenu; main.addItem(appItem)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "编辑")
        for (title, selector, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            edit.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        edit.addItem(item("搜索生化资料", #selector(focusSearch), key: "f"))
        editItem.submenu = edit; main.addItem(editItem); NSApp.mainMenu = main
    }
    private func addToolMenus(to menu: NSMenu) {
        let sections: [(String, [(String, Selector)])] = [
            ("Reference", [("氨基酸 · 20", #selector(openAmino)), ("官能团 · 24", #selector(openGroups))]),
            ("Sequence", [("Primer Tools", #selector(openPrimer)), ("DNA Tools", #selector(openDNA)), ("Translation", #selector(openTranslation))]),
            ("Protein", [("Protein Analyzer", #selector(openProtein))]),
            ("Calculators", [("Dilution", #selector(openDilution)), ("Molarity / Mass", #selector(openMolarity))])
        ]
        for (title, entries) in sections {
            let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            for (label, action) in entries { submenu.addItem(item(label, action)) }
            parent.submenu = submenu; menu.addItem(parent)
        }
    }
    private func showSettings() { NSApp.activate(ignoringOtherApps: true); settings?.makeKeyAndOrderFront(nil) }
    private func showMenuPreview() {
        showPetMenu(near: nil, at: NSEvent.mouseLocation)
    }
    private func showPetMenu(near anchor: NSRect?, at point: NSPoint) {
        menuAnchor = anchor
        defer { menuAnchor = nil }
        let menu = NSMenu(title: "生化工具")
        menu.addItem(item("打开生化工具", #selector(openLibrary)))
        addToolMenus(to: menu)
        menu.addItem(.separator())
        menu.addItem(item("连接设置…", #selector(openSettings)))
        let pause = item("暂停桥接", #selector(pauseBridge))
        pause.isEnabled = bridge?.isEnabled == true
        menu.addItem(pause)
        menu.addItem(.separator())
        let close = item("关闭资料窗口", #selector(closeLibrary))
        close.isEnabled = library?.panel.isVisible == true
        menu.addItem(close)
        menu.addItem(item("退出生化工具", #selector(quit)))
        menu.autoenablesItems = false
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: point, in: nil)
    }
    @objc private func openSettings() { showSettings() }
    @objc private func openLibrary() { library?.show(near: menuAnchor) }
    @objc private func openAmino() { library?.show(kind: .aminoAcid, near: menuAnchor) }
    @objc private func openPrimer() { library?.show(destination: .primer, near: menuAnchor) }
    @objc private func openDNA() { library?.show(destination: .dna, near: menuAnchor) }
    @objc private func openTranslation() { library?.show(destination: .translation, near: menuAnchor) }
    @objc private func openProtein() { library?.show(destination: .protein, near: menuAnchor) }
    @objc private func openDilution() { library?.show(destination: .dilution, near: menuAnchor) }
    @objc private func openMolarity() { library?.show(destination: .molarity, near: menuAnchor) }
    @objc private func openGroups() { library?.show(kind: .functionalGroup, near: menuAnchor) }
    @objc private func pauseBridge() { bridge?.setEnabled(false) }
    @objc private func closeLibrary() { library?.hide() }
    @objc private func focusSearch() { library?.show(destination: .reference); NotificationCenter.default.post(name: .bioChemFocusSearch, object: nil) }
    @objc private func closeWindow() { NSApp.keyWindow?.orderOut(nil) }
    @objc private func quit() { NSApp.terminate(nil) }
}

/// No bridge object, polling timer, or mouse monitor exists while the option is off.
@MainActor
private final class PetConnectionOptions: ObservableObject {
    private static let preferenceKey = "petConnectionEnabled"
    @Published private(set) var bridge: NativePetBridge?
    var configureBridge: ((NativePetBridge) -> Void)?
    var isEnabled: Bool { bridge != nil }

    func restorePreference() {
        setEnabled(UserDefaults.standard.bool(forKey: Self.preferenceKey))
    }
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if enabled {
            let bridge = NativePetBridge()
            configureBridge?(bridge)
            self.bridge = bridge
        } else {
            bridge?.shutdown()
            bridge = nil
        }
        UserDefaults.standard.set(enabled, forKey: Self.preferenceKey)
    }
}

private struct AppSettingsView: View {
    @ObservedObject var connection: PetConnectionOptions
    let onBind: () -> Void
    let onOpenLibrary: () -> Void
    let onPreviewMenu: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("桌宠连接").font(.system(size: 23, weight: .semibold))
                    Text("可选功能 · 生化查询可独立使用").foregroundStyle(.secondary).font(.subheadline)
                }
                Spacer()
                Toggle("连接 Codex 桌宠", isOn: Binding(get: { connection.isEnabled }, set: { connection.setEnabled($0) }))
                    .toggleStyle(.switch)
            }.padding(.horizontal, 25).padding(.top, 22)
            Divider()
            if let bridge = connection.bridge {
                ScrollView {
                    BridgeSettingsView(bridge: bridge, onBind: onBind, onOpenLibrary: onOpenLibrary, onPreviewMenu: onPreviewMenu)
                }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    Label("正在独立使用生化工具", systemImage: "atom").font(.headline)
                    Text("资料查询、序列分析与溶液计算均可直接使用，无需桌宠或辅助功能权限。")
                    Text("需要从桌宠右键打开资料时，开启上方选项，再授权并点选桌宠。关闭此选项会断开连接并停止鼠标监听。")
                        .foregroundStyle(.secondary)
                    Button("返回生化资料", action: onOpenLibrary).buttonStyle(.borderedProminent).tint(.teal)
                    Spacer()
                }.font(.system(size: 14)).lineSpacing(5).padding(25)
            }
        }.frame(width: 560, height: 730)
    }
}

private struct BridgeSettingsView: View {
    @ObservedObject var bridge: NativePetBridge
    let onBind: () -> Void
    let onOpenLibrary: () -> Void
    let onPreviewMenu: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill").font(.system(size: 36)).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置右键菜单").font(.system(size: 19, weight: .semibold))
                    Text("右键原来的桌宠，选择打开生化工具").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Label(bridge.status, systemImage: bridge.isEnabled ? "checkmark.circle.fill" : "info.circle")
                .font(.system(size: 13)).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("bridge-status")
            VStack(alignment: .leading, spacing: 9) {
                Text("1  允许识别桌宠").font(.headline)
                Text("辅助功能权限用于识别桌宠位置和显示右键菜单。左键仅用于点选绑定与判断拖动；不读取聊天内容、不监听键盘、不上传数据。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(bridge.trusted ? "权限已就绪" : "请求辅助功能权限") { bridge.requestPermission() }.disabled(bridge.trusted)
                    Button("打开系统设置") { bridge.openPermissionSettings() }
                }
                if !bridge.trusted {
                    HStack {
                        Button("刷新权限") { bridge.refreshPermission() }
                        Button("重启工具") { bridge.restartApplication() }
                        Button("显示当前应用") { bridge.revealCurrentApplication() }
                    }
                    Text("已开权限但按钮仍灰色：先刷新，再重启。更新版本后可能需要重新添加当前应用。")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                Text("2  点选原来的桌宠").font(.headline)
                Text("先在 Codex 中唤醒桌宠，再点下方按钮，20 秒内单击桌宠身体。确认绿色边框只围住桌宠。区域模式只在框内生效，拖动后须重新点选。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(bridge.isBound ? "重新点选桌宠" : "开始点选桌宠", action: onBind).disabled(!bridge.trusted || bridge.isArmed)
                    if bridge.hasCandidate {
                        Button("确认绑定") { bridge.confirmBinding() }.buttonStyle(.borderedProminent).tint(.teal)
                        Button("取消") { bridge.cancelBinding() }
                    }
                }
            }
            HStack {
                Toggle("启用右键菜单", isOn: Binding(get: { bridge.isEnabled }, set: { bridge.setEnabled($0) }))
                    .disabled(!bridge.isBound).toggleStyle(.switch)
                Spacer()
                Text("菜单已显示 \(bridge.activationCount) 次").font(.caption).foregroundStyle(.secondary)
            }
            Text("右键显示生化菜单，选择菜单项后才打开资料。左键保留桌宠原有动作，悬停不触发。Option + 右键保留原菜单。区域模式拖动后须重新点选。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("开关状态会保留；重启应用或重新开启后，需要重新点选桌宠。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("返回生化资料", action: onOpenLibrary)
                Button("预览右键菜单", action: onPreviewMenu)
                Spacer()
                if bridge.isBound { Button("清除绑定") { bridge.clearBinding() } }
            }
        }.padding(25).frame(width: 540)
    }
}
