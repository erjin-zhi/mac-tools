import SwiftUI
import SwitcherCore

final class SettingsModel: ObservableObject {
    @Published var accessibility = false
    @Published var screenRecording = false
    @Published var needsRestart = false
    @Published var checkingPermissions = false
    @Published var running = false
    @Published var enabled = true
    @Published var delay = 0.25
    @Published var activationKey: ActivationKey = .command
    @Published var status = ""
    @Published var updates: UpdateService?
    var refresh: (() -> Void)?
    var requestAccessibility: (() -> Void)?
    var requestRecording: (() -> Void)?
    var demo: (() -> Void)?
    var toggle: ((Bool) -> Void)?
    var changeDelay: ((Double) -> Void)?
    var changeActivationKey: ((ActivationKey) -> Void)?
    var restart: (() -> Void)?
    let icon = IconArtwork.appImage(size: 136)

    func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<SettingsModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        ScrollView { settingsContent }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: 620, height: min(740, max(400, (NSScreen.main?.visibleFrame.height ?? 820) - 80)))
            .background(Color(red: 0.07, green: 0.085, blue: 0.10))
            .environment(\.colorScheme, .dark)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                Image(nsImage: model.icon)
                    .resizable().frame(width: 68, height: 68)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Window Peek").font(.system(size: 28, weight: .bold))
                    Text("同一个应用，每个窗口一眼找到。")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(model.activationKey.symbol).font(.system(size: 23, weight: .medium)).frame(width: 44, height: 38)
                        .background(.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("长按预览").font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text("1–9 选择").font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text("松开切换").font(.system(size: 15, weight: .semibold))
                }
                Text("也可以用 ← → 或 \(model.activationKey.name) + ` 循环选择，Esc 取消，点击预览直接切换。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 15) {
                Text("使用权限").font(.system(size: 14, weight: .semibold))
                permissionRow("辅助功能", detail: "识别快捷键，并将选中的窗口带到前台", symbol: "hand.point.up.left", granted: model.accessibility, action: model.requestAccessibility)
                Divider()
                permissionRow("屏幕与系统音频录制", detail: "仅在预览时截取窗口画面，不录音、不保存截图", symbol: "rectangle.dashed.badge.record", granted: model.screenRecording, needsRestart: model.needsRestart, action: model.requestRecording)
            }

            VStack(spacing: 16) {
                Toggle("启用窗口切换", isOn: Binding(get: { model.enabled }, set: { model.toggle?($0) }))
                    .toggleStyle(.switch).tint(.mint)
                HStack {
                    Text("激活键")
                    Spacer()
                    Picker("激活键", selection: Binding(get: { model.activationKey }, set: { model.changeActivationKey?($0) })) {
                        ForEach(ActivationKey.allCases) { key in
                            Text("\(key.symbol) \(key.name)").tag(key)
                        }
                    }.labelsHidden().frame(width: 155)
                }
                HStack {
                    Text("长按触发时间")
                    Spacer()
                    Picker("长按触发时间", selection: Binding(get: { model.delay }, set: { model.changeDelay?($0) })) {
                        Text("0.15 秒").tag(0.15)
                        Text("0.25 秒（默认）").tag(0.25)
                        Text("0.4 秒").tag(0.4)
                        Text("0.6 秒").tag(0.6)
                    }.labelsHidden().frame(width: 120)
                }
            }.font(.system(size: 13))
            if let updates = model.updates { UpdateSettingsView(service: updates) }
            HStack {
                Circle().fill(model.running ? .mint : .orange).frame(width: 7, height: 7)
                Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("查看演示") { model.demo?() }
                Button(model.checkingPermissions ? "检查中…" : "刷新权限") { model.refresh?() }
                    .disabled(model.checkingPermissions)
            }
            HStack(alignment: .center, spacing: 12) {
                Text(model.needsRestart ? "系统已记录授权，重新启动后即可使用。" : "在系统设置中已开启，但这里未更新？可刷新权限或重新启动。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("重新启动") { model.restart?() }
            }
        }
        .padding(30).frame(width: 620)
    }

    private func permissionRow(_ title: String, detail: String, symbol: String, granted: Bool, needsRestart: Bool = false, action: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label(needsRestart ? "已授权 · 需重启" : "已开启", systemImage: needsRestart ? "arrow.clockwise.circle" : "checkmark.circle.fill")
                    .font(.system(size: 12)).foregroundStyle(needsRestart ? Color.orange : Color.mint)
            } else {
                Button("去开启") { action?() }.controlSize(.small)
            }
        }
    }
}

private struct UpdateSettingsView: View {
    @ObservedObject var service: UpdateService
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("软件更新").font(.system(size: 14, weight: .semibold))
                Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("检查更新…") { service.check() }.disabled(!service.canCheck)
            }
            Toggle("自动检查更新", isOn: Binding(get: { service.automaticallyChecks }, set: { service.setAutomaticallyChecks($0) }))
                .toggleStyle(.switch).tint(.mint).font(.system(size: 13))
            Text("运行期间每天检查一次，发现新版本后由你选择安装。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
