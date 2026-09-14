import SwiftUI
import AppKit
import SwitcherCore

final class SwitcherModel: ObservableObject {
    @Published var activationKey: ActivationKey = .command
    @Published var windows: [WindowItem] = []
    @Published var selection = 0
    @Published var loading = true
    @Published var appName = ""
    @Published var appIcon: NSImage?
    @Published var cardWidth: CGFloat = 224
    var select: ((Int) -> Void)?
    var confirm: (() -> Void)?
    var visibleWindowsChanged: ((Set<UUID>) -> Void)?
}

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 11) {
                if let icon = model.appIcon {
                    Image(nsImage: icon).resizable().frame(width: 32, height: 32)
                } else {
                    Image(systemName: "macwindow.on.rectangle").font(.system(size: 26)).foregroundStyle(.mint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.appName).font(.system(size: 16, weight: .semibold))
                    Text(model.loading ? "正在查找窗口…" : "\(model.windows.count) 个窗口 · 按编号快速选择")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<min(9, model.windows.count), id: \.self) { index in
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 25, height: 27)
                            .background(model.selection == index ? Color.mint.opacity(0.85) : Color.white.opacity(0.08))
                            .foregroundStyle(model.selection == index ? Color.black : Color.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
                    }
                }
            }
            if model.loading {
                HStack(spacing: 12) { ProgressView().controlSize(.small); Text("正在读取当前应用的窗口").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity).frame(height: 184)
            } else if model.windows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "macwindow").font(.system(size: 34)).foregroundStyle(.secondary)
                    Text("这个应用没有可切换的窗口").font(.system(size: 14))
                    Text("松开 \(model.activationKey.name) 返回").font(.system(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 184)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                                WindowCard(window: window, index: index, selected: model.selection == index, width: model.cardWidth)
                                    .id(index)
                                    .background(GeometryReader { geometry in
                                        Color.clear.preference(key: VisibleWindowFrames.self,
                                            value: WindowLayout(frames: [window.id: geometry.frame(in: .named("windowStrip"))]))
                                    })
                                    .onTapGesture { model.select?(index); model.confirm?() }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("窗口 \(index + 1)，\(window.title)\(window.minimized ? "，已最小化" : "")")
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityValue(model.selection == index ? "已选择" : "")
                                    .accessibilityAction { model.select?(index); model.confirm?() }
                            }
                        }.padding(3)
                    }
                    .coordinateSpace(name: "windowStrip")
                    .background(GeometryReader { viewport in
                        Color.clear.preference(key: VisibleWindowFrames.self, value: WindowLayout(viewport: viewport.size))
                    })
                    .onPreferenceChange(VisibleWindowFrames.self) { layout in
                        let visible = layout.frames.filter { $0.value.intersects(CGRect(origin: .zero, size: layout.viewport)) }
                        // Avoid changing an ObservableObject during the layout pass.
                        DispatchQueue.main.async { model.visibleWindowsChanged?(Set(visible.keys)) }
                    }
                    .onChange(of: model.selection) { _, index in
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(index, anchor: .center) }
                    }
                    .onAppear { proxy.scrollTo(model.selection, anchor: .center) }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("按住")
                    ShortcutKeycap(symbol: model.activationKey.symbol)
                    Text("＋").foregroundStyle(.secondary)
                    ShortcutKeycap(symbol: "`")
                    Text("反复按反引号，循环选择同一 App 的窗口")
                }
                .font(.system(size: 12))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("按住 \(model.activationKey.name)，反复按反引号键，循环选择同一 App 的窗口")
                HStack(spacing: 7) {
                    Text("松开 \(model.activationKey.symbol) 确认切换").foregroundStyle(.primary)
                    Text("·  ← → 选择  ·  Esc 取消").foregroundStyle(.secondary)
                    Spacer()
                    Text(model.windows.count > 9 ? "前 9 个支持数字直达" : "按编号快速选择")
                        .foregroundStyle(.secondary)
                }.font(.system(size: 11))
            }
        }
        .padding(24)
        .background(VisualEffect().overlay(Color(red: 0.055, green: 0.07, blue: 0.085).opacity(0.74)))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }
}

private struct ShortcutKeycap: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 20, weight: .medium, design: .monospaced))
            .foregroundStyle(.mint)
            .frame(width: 36, height: 30)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 0, y: 2)
    }
}

private struct WindowCard: View {
    let window: WindowItem
    let index: Int
    let selected: Bool
    let width: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.black.opacity(0.25)
                if let image = window.image {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(width: max(0, width - 14), height: 128)
                } else if window.previewUnavailable {
                    VStack(spacing: 10) {
                        Image(systemName: window.minimized ? "minus.rectangle" : "macwindow")
                            .font(.system(size: 30, weight: .ultraLight))
                        Text("暂时无法预览")
                            .font(.system(size: 11))
                    }.foregroundStyle(.secondary)
                }
                VStack {
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .frame(minWidth: 26, minHeight: 26)
                            .background(selected ? Color.mint : Color.black.opacity(0.78))
                            .foregroundStyle(selected ? .black : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        Spacer()
                        if window.minimized {
                            Text("已最小化").font(.system(size: 9)).padding(.horizontal, 7).padding(.vertical, 5)
                                .background(.black.opacity(0.75)).clipShape(Capsule())
                        }
                    }
                    Spacer()
                }.padding(10)
            }.frame(width: width, height: 142)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
            HStack(spacing: 7) {
                Circle().fill(selected ? .mint : .clear).frame(width: 5, height: 5)
                Text(window.title).font(.system(size: 12, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 0)
            }.padding(.horizontal, 11).frame(height: 38)
                .background(selected ? Color.mint.opacity(0.12) : Color.white.opacity(0.045))
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.mint : Color.white.opacity(0.09), lineWidth: selected ? 2 : 1))
        .help(window.title)
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

final class SwitcherPanel: NSPanel {
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        animationBehavior = .none
        isReleasedWhenClosed = false
    }
}

private struct WindowLayout: Equatable {
    var frames: [UUID: CGRect] = [:]
    var viewport: CGSize = .zero
}

private struct VisibleWindowFrames: PreferenceKey {
    static var defaultValue = WindowLayout()
    static func reduce(value: inout WindowLayout, nextValue: () -> WindowLayout) {
        let next = nextValue()
        value.frames.merge(next.frames, uniquingKeysWith: { _, new in new })
        if next.viewport != .zero { value.viewport = next.viewport }
    }
}
