import SwiftUI
import AppKit

struct CustomToggleStyle: ToggleStyle {
    var tintColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
            Spacer(minLength: 8)

            RoundedRectangle(cornerRadius: 14)
                .fill(configuration.isOn ? tintColor : Color(hex: "D7DBD3"))
                .frame(width: 46, height: 27)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.16), radius: 2, x: 0, y: 1)
                        .padding(3)
                        .offset(x: configuration.isOn ? 9.5 : -9.5)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var tintColor: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "DBDFD8"))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(tintColor)
                    .frame(width: progress(in: geometry.size.width), height: 6)

                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.14), radius: 3, x: 0, y: 1)
                    .frame(width: 16, height: 16)
                    .offset(x: progress(in: geometry.size.width) - 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                updateValue(in: geometry.size.width, at: gesture.location.x)
                            }
                    )
            }
            .frame(height: 16)
        }
        .frame(height: 16)
    }

    private func progress(in width: CGFloat) -> CGFloat {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(normalizedValue) * width
    }

    private func updateValue(in width: CGFloat, at location: CGFloat) {
        let normalizedValue = max(0, min(1, location / width))
        let raw = range.lowerBound + normalizedValue * (range.upperBound - range.lowerBound)
        let stepped = round(raw / step) * step
        value = max(range.lowerBound, min(range.upperBound, stepped))
    }
}

struct SettingsView: View {
    @State private var currentPath: String
    @State private var showReloadAlert = false

    @ObservedObject private var shortcutSettings = ShortcutSettings.shared
    @ObservedObject private var updateService = GitHubUpdateService.shared

    let onPathChanged: () -> Void

    init(onPathChanged: @escaping () -> Void) {
        self.onPathChanged = onPathChanged
        _currentPath = State(initialValue: FileStorageService.shared.storageDirectory.path)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "F2F6F1"), Color(hex: "F8F9F5")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerSection

                    SettingsCard(
                        title: "外观",
                        subtitle: "Dock 图标与显示行为"
                    ) {
                        Toggle(isOn: $shortcutSettings.showDockIcon) {
                            Text("在 Dock 中显示图标")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "3B433E"))
                        }
                        .toggleStyle(CustomToggleStyle(tintColor: Color(hex: "6E8B77")))

                        sectionHint("需要重启应用才能完全生效")
                    }

                    SettingsCard(
                        title: "存储",
                        subtitle: "Markdown 文件位置"
                    ) {
                        Text(currentPath)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "515A54"))
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "F3F6F1"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "E1E7DE"), lineWidth: 1)
                                    )
                            )

                        HStack(spacing: 8) {
                            SettingsPrimaryButton(title: "选择文件夹") {
                                selectFolder()
                            }

                            SettingsGhostButton(title: "重置路径") {
                                resetToDefault()
                            }
                        }

                        sectionHint("便签以 .md 文件存储")
                    }

                    SettingsCard(
                        title: "窗口",
                        subtitle: "自动隐藏行为"
                    ) {
                        Toggle(isOn: $shortcutSettings.autoHideOnMouseExit) {
                            Text("鼠标移出时自动隐藏")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "3B433E"))
                        }
                        .toggleStyle(CustomToggleStyle(tintColor: Color(hex: "6E8B77")))

                        if shortcutSettings.autoHideOnMouseExit {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("隐藏延迟")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "5C645E"))

                                    Spacer()

                                    Text(String(format: "%.1f 秒", shortcutSettings.hideDelay))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "6E8B77"))
                                }

                                CustomSlider(
                                    value: $shortcutSettings.hideDelay,
                                    range: 0.0...3.0,
                                    step: 0.1,
                                    tintColor: Color(hex: "6E8B77")
                                )
                            }
                            .padding(.top, 2)
                        }

                        sectionHint("控制应用窗口何时自动隐藏")
                    }

                    SettingsCard(
                        title: "键盘快捷键",
                        subtitle: "全局切换键"
                    ) {
                        HStack(alignment: .center, spacing: 10) {
                            Text("切换窗口")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "3B433E"))
                                .frame(width: 110, alignment: .leading)

                            ShortcutRecorderView(shortcut: $shortcutSettings.toggleWindowShortcut)
                        }
                    }

                    SettingsCard(
                        title: "更新",
                        subtitle: "版本与发布信息"
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前版本：v\(updateService.currentVersion)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "3B433E"))

                            if let latest = updateService.latestVersion {
                                Text(updateService.hasNewVersion() ? "最新版本：v\(latest)（有新版本）" : "最新版本：v\(latest)（已是最新）")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(updateService.hasNewVersion() ? Color(hex: "5F896F") : Color(hex: "818A82"))
                            }

                            if let error = updateService.checkError {
                                Text(error)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "C56161"))
                            }
                        }

                        SettingsPrimaryButton(title: updateService.isChecking ? "检查中…" : "检查更新", isDisabled: updateService.isChecking) {
                            Task {
                                await updateService.checkForUpdates(silent: false)
                            }
                        }

                        sectionHint("自动检查更新频率：每天")
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 650)
        .alert("需要重新加载", isPresented: $showReloadAlert) {
            Button("立即重新加载", role: .none) {
                onPathChanged()
            }
            Button("稍后", role: .cancel) { }
        } message: {
            Text("存储位置已更改。是否重新加载便签以查看新位置的文件？")
        }
        .sheet(isPresented: $updateService.showUpdateAlert) {
            UpdateAlertView(updateService: updateService)
        }
        .animation(.easeInOut(duration: 0.2), value: shortcutSettings.autoHideOnMouseExit)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color(hex: "27302A"))

            Text("调整工作区行为、存储与更新偏好")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "7C857E"))
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private func sectionHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(Color(hex: "909990"))
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "选择存储便签的文件夹"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            currentPath = url.path
            FileStorageService.shared.storageDirectory = url
            showReloadAlert = true
        }
    }

    private func resetToDefault() {
        let defaultPath = Constants.defaultNotesDirectory()
        currentPath = defaultPath.path
        FileStorageService.shared.storageDirectory = defaultPath
        showReloadAlert = true
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "2D352F"))

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "818A82"))
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
    }
}

private struct SettingsPrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(isDisabled ? Color(hex: "A9B8AE") : Color(hex: "6E8B77"))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct SettingsGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "5B655E"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(hex: "EBEFE8"))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(onPathChanged: {})
}
