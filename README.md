# Biochem Tool Kit

macOS 原生生化小工具：Swift + SwiftUI + AppKit、本地 JSON、离线查询。默认独立使用；连接 Codex 桌宠是 App 内的可选功能。

**当前仓库仅发布源码，不提供预编译 `.app`、`.dmg` 或 GitHub Release。** 当前应用版本为 0.5.0；正式 macOS 分发仍在准备中。下面的构建步骤面向开发者，普通用户的直接下载版本尚未发布。

## 本地构建后使用

打开 `outputs/BioChem Bridge.app` 后直接进入生化资料库，可查询 20 种标准氨基酸、24 种官能团及搜索。无需先连接桌宠，也无需为资料查询授权辅助功能。应用显示在 Dock；关闭资料窗口后，可点击 Dock 图标或菜单栏原子图标重新打开。

主界面右上角“设置”、菜单栏“设置 · 可选桌宠连接…”以及快捷键 ⌘, 都能进入设置。

## 可选：连接 Codex 桌宠

1. 在设置中开启“连接 Codex 桌宠”（首次默认关闭，保存开关状态）。
2. 仅此功能需要辅助功能权限。在 **系统设置 → 隐私与安全性 → 辅助功能** 中开启当前应用。已有授权时可直接点选。
3. 在 Codex 中唤醒桌宠，点击“开始点选桌宠”，20 秒内单击桌宠身体。
4. 确认绿色边框只围住桌宠，然后点击“确认绑定”。没有独立控件时使用明确确认过的窗口内小区域。
5. 此后**右键桌宠 → 打开生化工具**，或从 Reference / Sequence / Protein / Calculators 二级菜单直接进入工具。菜单中“关闭资料窗口”只收起资料；“退出生化工具”关闭整个应用并停止连接。左键保留原有动作，悬停不触发；Option + 右键保留原菜单。

关闭“连接 Codex 桌宠”会停止事件监听、取消点选计时器、清除绑定并释放连接模块；生化查询继续使用。关闭设置窗口不会断开连接。“启用右键菜单”可临时暂停已绑定的菜单；总开关关闭则彻底断开。

开关状态会保留，但桌宠绑定只保存在内存中。重启应用、重新开启连接或区域模式下拖动后，须重新点选。即使保存为开启，应用启动时仍优先显示资料库，不会自动弹出授权框或点选窗口。

**已授权但点选按钮仍为灰色：** 点击“刷新权限”，必要时“重启工具”。若旧授权因更新失效，在系统辅助功能列表移除旧条目，再通过“显示当前应用”定位当前版本并重新添加。为延续原有应用身份，包路径仍为 `BioChem Bridge.app`，Bundle ID 保持不变，界面显示为 BioChem 生化速查。

**兼容性边界：** 这不是官方桌宠插件。菜单由独立桥接程序显示，并非向 Codex 原生菜单插入选项。桥接只读取辅助功能几何信息，不修改客户端或宠物文件；启用后拦截命中已确认桌宠的无修饰键右键序列，避免同时弹出两套菜单。菜单在右键松开后显示；右键拖动、移出目标或加修饰键会取消弹出。其他位置和带 Option 的右键不拦截。若无法建立事件监听，会显示失败原因，不会假装已启用。若没有合适的小型辅助功能元素，但能识别所属窗口，使用用户明确确认过的窗口内小区域。它验证同一窗口、进程和命中关系，并在窗口改尺寸或从绑定区域拖动时失效；不会把整个窗口或任意屏幕坐标作为目标。若连所属窗口范围也不可读，则拒绝绑定。

## 权限与数据

辅助功能权限只用于识别点选元素的进程、类型、父级关系和几何位置。桥接程序不读取 AXValue、聊天文本或剪贴板，不监听键盘，不模拟点击，不申请屏幕录制权限，不上传数据。左键监听仅用于首次点选与区域拖动失效判定；右键事件监听仅在确认绑定并启用后启动。暂停或权限撤销时停止监听，没有鼠标悬停监听。

点选只接受 `com.openai.codex` 或 `com.openai.chat` 进程。确认前会描绘识别范围；绑定后会再次验证点击所属进程与元素关系，拒绝被其他窗口覆盖的点击。只凭大小不能判断一个元素就是桌宠，因此首次人工确认十分必要。区域模式不能自动跟随宠物在同一窗口内部的布局变化；移动、换宠物或布局改变后必须重新点选。

## 内容

- 20 种标准氨基酸：中英文名、单字母/三字母缩写、侧链、pH 7 典型侧链电性、分类。
- 24 种官能团：中英文名、缩合通式、简要说明、来源。
- 中文、英文、缩写、别名、多关键词搜索，以及分类筛选。
- 保留 JSON 与视图分层；氨基酸预留完整 SVG，现有醛、酮、酰胺 SVG 示例。
- 电性表示侧链主要状态。组氨酸保留部分质子化说明，脯氨酸使用环状骨架示意。

## 分析与计算工具

顶部“BioChem”菜单按 Reference / Sequence / Protein / Calculators 分组。菜单栏与可选桌宠右键菜单使用二级菜单，避免一次铺满按钮。切换页面保留本次会话输入；退出应用后序列输入不保存。常用结果旁可点击复制，序列与完整报告另有复制按钮。外观默认跟随系统，也可在工具窗口选择浅色或深色。

- **Primer Tools**：DNA 自动去空白并大写，非法字符明确报错；显示长度、GC/AT%、无修饰单链 MW、反向互补序列，以及 Wallace 和 GC/Na⁺ 两种 Estimated Tm。支持输入一对引物、选择 Tm 方法、查看 ΔTm 和估计退火温度范围。
- **Protein Analyzer**：20 种标准氨基酸单字母序列或单条 FASTA；显示长度、Theoretical MW / pI、氨基酸组成、酸性/碱性/芳香族残基数、Trp/Tyr/Cys 数、平均残基质量及两种二硫键假设下的 ε₂₈₀。
- **Sequence Tools**：DNA 长度、GC%、reverse、complement、reverse complement；Translation 支持标准遗传密码表、三个正向 reading frames、是否遇到 stop codon 停止，并提示末尾不足一个密码子的碱基数。
- **Calculators**：稀释计算任选 C1/V1/C2/V2 中一个未知量；Molarity / Mass 根据分子量、浓度及最终体积计算质量。支持 M/mM/μM、L/mL/μL、g/mg/μg，内部统一基础单位。

**Tm、protein pI、protein MW 和退火范围均为 theoretical / estimated values，绝非实验测定值。** 适合 quick laboratory reference、experiment preparation 和 sequence inspection，不能替代专业分析软件或实验验证。General Tm 为带 Na⁺ 项的经验式，并非 nearest-neighbor；pI 使用 Bjellqvist pKa 和电荷数值求根；MW 按残基质量并正确计入肽键失水。全部公式、pKa、输入规则及局限见 [计算方法说明](docs/CALCULATIONS.md)。

输入与计算均在本地内存中完成，不发送网络请求。点击复制会将所选结果写入系统剪贴板。DNA 不接受模糊碱基或 FASTA；蛋白质一次接受一条 FASTA，不会自动拼接多条记录。单次最多 100,000 个碱基/残基。

## 工程

- `Sources/BioChemCore`：资料 JSON、搜索、右键规则；`Models/` 为计算结果及单位模型，`Services/` 为计算服务，`Data/` 为残基质量、pKa 与密码表。
- `Sources/BioChemUI`：原资料视图与 NSPanel；`ToolkitView` 提供分组导航，`Modules/` 包含各分析页面与共享控件。
- `Sources/BioChemPet/NativePetBridge.swift`：辅助功能位置识别、右键事件接管、点选、确认、暂停与失效处理。
- `Sources/BioChemPet/App.swift`：连接设置、菜单栏、右键菜单预览。
- `Checks/main.swift`：无需 XCTest 的可执行回归检查。
- `Tests/Support`：26 组新计算检查，供命令行与 XCTest 共用。
- `Tests/BioChemCoreTests`：原资料 XCTest 和新增计算 XCTest（需要包含 XCTest 的完整 Xcode 工具链）。

构建需要 macOS 13 或更新版本、Swift 5.9 或更新版本（来自兼容的 Xcode / Command Line Tools），以及构建辅助脚本使用的 Python 3。当前已验证环境为 Apple Silicon、macOS 15.3.2、Swift 6.1.2；尚未验证 Intel 构建。Python 仅在构建时使用，生成的应用运行时不依赖 Python、Node 或 Homebrew。

构建与检查：

```sh
./scripts/swift-local.sh build
./scripts/swift-local.sh run BioChemCheck
./scripts/build-app.sh
open 'outputs/BioChem Bridge.app'
```

构建脚本针对本机 Command Line Tools 遗留的私有接口与重复模块声明，使用工程内的临时文件映射；不修改系统开发工具。Apple Silicon 上输出 arm64 应用，采用本地 ad-hoc 签名，未做 Developer ID 公证。更新构建后，macOS 可能要求重新确认辅助功能授权。

有完整 Xcode 并将开发工具目录指向它时，还可运行：

```sh
./scripts/swift-local.sh test
```

当前仅装 Command Line Tools 的环境缺少 XCTest，`swift test` 会报告 `no such module 'XCTest'`。`BioChemCheck` 不依赖 XCTest，运行原有 62 项回归检查和新增 26 组共享计算检查；此次共 88 项通过。不能将命令行检查通过等同于 XCTest runner 已运行成功。

## 验证范围

应用不再创建测试桌宠或独立桌面悬浮球。“预览右键菜单”直接在设置中打开与桌宠共用的菜单，不生成另一只桌宠；可验证打开、关闭资料和退出。预览不代表已经测试真实 Codex 桌宠的辅助功能结构。

当前自动化工具禁止读取或操作 Codex 本体，因此真实桌宠的元素绑定及端到端右键菜单需要用户在本机完成。若点选失败，请提供设置窗口显示的具体状态；不应绕过这个限制去修改或注入 Codex 客户端。

## 资料与参考

化学条目来源随 JSON 保存并在面板中展示：NCBI Bookshelf、OpenStax、IUPAC。

- [官方桌宠说明](https://learn.chatgpt.com/docs/pets)
- [Apple — Monitoring Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)
- [Apple — AXUIElementCopyElementAtPosition](https://developer.apple.com/documentation/applicationservices/1462077-axuielementcopyelementatposition)
