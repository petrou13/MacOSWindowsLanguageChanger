import SwiftUI
import AppKit
import ServiceManagement

final class AppModel: ObservableObject {
    let engine = LanguageEngine()
    let appearance = MenuAppearance()
    private var tokens: [NSObjectProtocol] = []
    @Published var loginEnabled = false
    @Published var loginMessage = ""
    @Published var sample = ""
    @Published var tab: SettingsTab = .switching
    @Published var diagnosticsShown = false {
        didSet { engine.diagnosticVisible = diagnosticsShown }
    }
    init() {
        tokens.append(NotificationCenter.default.addObserver(forName: Notification.Name("LanguageEngineChanged"), object: engine, queue: .main) { [weak self] _ in
            self?.objectWillChange.send()
            NotificationCenter.default.post(name: Notification.Name("LanguageMenuRefresh"), object: nil)
        })
        tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.recheck() })
        engine.start()
        recheck()
    }
    func recheck() {
        engine.recheck()
        loginEnabled = SMAppService.mainApp.status == .enabled
    }
    var accessModeName: String { engine.accessMode == 1 ? "Универсальный доступ" : "Мониторинг ввода" }
    func setAccessMode(_ mode: Int) {
        engine.accessMode = mode
        recheck()
    }
    func openSelectedAccess() {
        if engine.accessMode == 1 { engine.requestSystemSwitchPermission() }
        else { engine.requestPermission() }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = ""
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { loginMessage = error.localizedDescription }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }
    var status: String {
        if !engine.enabled { return "Переключение на паузе" }
        if engine.remote { return "RDP: клавиши без изменений" }
        if !engine.permitted { return "Разрешите \(accessModeName.lowercased())" }
        if !engine.listening { return "Мониторинг недоступен — проверьте разрешение" }
        return "Готово к переключению"
    }
    var shortcutName: String { ["Shift + Command", "Option + Shift", "Control + Shift"][engine.shortcut] }
    func keyboardSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) }
}

enum SettingsTab: Hashable { case switching, remote, system, appearance, about }

struct PageIntro: View {
    let symbol: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 25, weight: .medium)).foregroundStyle(.tint)
                .frame(width: 44, height: 44).background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 6)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        TabView(selection: $model.tab) {
            switching.tabItem { Label("Переключение", systemImage: "keyboard") }.tag(SettingsTab.switching)
            MenuAppearanceView(appearance: model.appearance).tabItem { Label("Строка меню", systemImage: "menubar.rectangle") }.tag(SettingsTab.appearance)
            remote.tabItem { Label("RDP", systemImage: "desktopcomputer") }.tag(SettingsTab.remote)
            system.tabItem { Label("Основные", systemImage: "gearshape") }.tag(SettingsTab.system)
            about.tabItem { Label("О приложении", systemImage: "info.circle") }.tag(SettingsTab.about)
        }.padding(12).frame(width: 660, height: 600)
    }
    private var switching: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "keyboard", title: "Привычное переключение языка", subtitle: "На Mac — как в Windows. Без переназначения клавиш.")
            Form {
                Section {
                    HStack {
                        Label(model.status, systemImage: model.engine.listening ? "checkmark.circle" : "circle.dashed")
                        Spacer()
                        Text(model.engine.languageCode).font(.headline.monospaced()).foregroundStyle(.secondary)
                    }
                    Toggle("Включить переключение", isOn: Binding(get: { model.engine.enabled }, set: { model.engine.enabled = $0 }))
                    Picker("Сочетание", selection: Binding(get: { model.engine.shortcut }, set: { model.engine.shortcut = $0 })) {
                        Text("⇧ Shift + ⌘ Command").tag(0)
                        Text("⌥ Option + ⇧ Shift").tag(1)
                        Text("⌃ Control + ⇧ Shift").tag(2)
                    }
                } header: { Text("Клавиши") } footer: {
                    Text("Зажмите одну клавишу, затем вторую — в любом порядке. После отпускания обеих язык сменится. Ограничения по времени нет.")
                }
                switchingMode
                Section {
                    LabeledContent("Текущая раскладка", value: model.engine.languageName)
                    TextField("Нажмите сочетание и напечатайте несколько букв", text: $model.sample)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Проверка раскладки")
                    HStack {
                        Button("Переключить сейчас") { model.engine.switchLanguage() }
                        Spacer()
                        Button("Обновить") { model.recheck() }
                    }
                    if !model.engine.message.isEmpty { Text(model.engine.message).foregroundStyle(.red) }
                    Button { model.diagnosticsShown.toggle() } label: {
                        HStack {
                            Image(systemName: model.diagnosticsShown ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold)).frame(width: 14)
                            Text("Диагностика сочетания")
                            Spacer()
                        }.frame(maxWidth: .infinity, minHeight: 28, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityValue(model.diagnosticsShown ? "Развёрнуто" : "Свёрнуто")
                    if model.diagnosticsShown {
                        Text(model.engine.diagnostic).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                } header: { Text("Проверка и диагностика") } footer: {
                    Text("Сочетание с буквой, например Command + Shift + F, остаётся обычной горячей клавишей и не меняет язык.")
                }
            }.formStyle(.grouped)
        }
    }
    @ViewBuilder
    private var switchingMode: some View {
        Section {
            Picker("Режим доступа", selection: Binding(get: { model.engine.accessMode }, set: { model.setAccessMode($0) })) {
                Text("Мониторинг ввода — базовый функционал").tag(0)
                Text("Универсальный доступ — системное сочетание").tag(1)
            }
            Text(model.engine.accessMode == 0 ? "Прямая смена раскладки. Требуется только «Мониторинг ввода»." : "Смена языка через штатное сочетание macOS. Требуется только «Универсальный доступ».")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Label(model.engine.permitted ? "Доступ предоставлен" : "Нет доступа: \(model.accessModeName)", systemImage: model.engine.permitted ? "checkmark.shield" : "exclamationmark.triangle")
                    .foregroundStyle(model.engine.permitted ? Color.secondary : Color.orange)
                Spacer()
                Button("Открыть настройки доступа…") { model.openSelectedAccess() }
            }
            if !model.engine.permitted {
                Text("Включите приложение в соответствующем списке macOS. Если его нет, добавьте кнопкой «+».")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        } header: { Text("Способ переключения и доступ") }
        Section {
            Label("Значок возле текстового курсора", systemImage: "character.cursor.ibeam")
            Text(model.engine.systemSwitchStatus)
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.engine.accessMode == 1 {
                Button("Настроить системное сочетание…") { model.keyboardSettings() }
            }
        } header: { Text("Индикация смены языка") } footer: {
            Text("Встроенный значок рисует macOS. Отображение раскладки и значок приложения в строке меню настраиваются в разделе «Строка меню».")
        }
    }
    private var remote: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "desktopcomputer", title: "Горячие клавиши рабочего сервера", subtitle: "Поведение при активном окне Windows App или Microsoft Remote Desktop.")
            Form {
                Section {
                    Toggle("Отключать переключатель в RDP", isOn: Binding(get: { model.engine.excludeRDP }, set: { model.engine.excludeRDP = $0 }))
                    Text(model.engine.excludeRDP ? "В активном Windows App мониторинг и переключение выключены. После перехода в другое приложение переключатель снова работает." : "Переключатель работает и при активном Windows App. Он меняет раскладку на Mac; реакция удалённого сервера зависит от настроек клиента RDP.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } header: { Text("Поведение в RDP") }
                Section {
                    LabeledContent("Command и Option", value: "Без переназначения")
                    LabeledContent("Option + Shift + F", value: "Без изменений")
                    Text("Конечное действие сочетания определяется настройками Windows App и приложения на сервере.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } header: { Text("Сохранение сочетаний") }
                Section {
                    Text("Если вы пользовались другой утилитой, отключите её и отмените сделанные ею переназначения модификаторов.")
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Открыть настройки клавиатуры…") { model.keyboardSettings() }
                } header: { Text("После других утилит") }
            }.formStyle(.grouped)
        }
    }
    private var system: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "gearshape", title: "Поведение приложения", subtitle: "Автозапуск и приватность.")
            Form {
                Section {
                    Toggle("Запускать при входе в macOS", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    if !model.loginMessage.isEmpty { Text(model.loginMessage).foregroundStyle(.red) }
                } header: { Text("Автозапуск") } footer: {
                    Text("Храните приложение в постоянном месте, например в папке «Программы».")
                }
                Section {
                    Label("Введённый текст не сохраняется", systemImage: "lock")
                    Label("Сетевые запросы не выполняются", systemImage: "network.slash")
                    DisclosureGroup("Как уменьшается нагрузка") {
                        Text("Один наблюдатель событий без постоянного опроса. Он распознаёт модификаторы и факт добавления другой клавиши, не сохраняя текст. После смены языка выполняется короткая серия обновлений индикатора. На паузе и в RDP при включённом исключении мониторинг выключен.")
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
                    }
                } header: { Text("Приватность") }
            }.formStyle(.grouped)
        }
    }
    private var about: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage()).resizable().frame(width: 76, height: 76).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("MacOSWindowsLanguageChanger").font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                    Text("Windows-style language switching for macOS").foregroundStyle(.secondary)
                    Text("Версия 2.7.1 · macOS 13 и новее").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Form {
                Section {
                    Text("Переключение языка на Mac через Shift + Command, Option + Shift или Control + Shift. Исключение для Windows App настраивается на вкладке RDP.")
                        .fixedSize(horizontal: false, vertical: true)
                } header: { Text("Для чего приложение") }
            }.formStyle(.grouped)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    var item: NSStatusItem!
    var window: NSWindow!
    var refreshToken: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let ownVersion = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        for other in others {
            let otherVersion = other.bundleURL.flatMap { Bundle(url: $0) }.flatMap { $0.object(forInfoDictionaryKey: "CFBundleVersion") as? String }.flatMap(Int.init) ?? 0
            if otherVersion > ownVersion || other.bundleURL == Bundle.main.bundleURL {
                other.activate(options: [.activateIgnoringOtherApps])
                NSApp.terminate(nil); return
            }
            // If the user opens an installed copy of the same version, let THAT
            // copy run rather than silently keeping a different build path alive.
            other.terminate()
        }
        model = AppModel()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacOSWindowsLanguageChanger")
        item.button?.imagePosition = .imageLeading
        refreshToken = NotificationCenter.default.addObserver(forName: Notification.Name("LanguageMenuRefresh"), object: nil, queue: .main) { [weak self] _ in self?.refreshMenu() }
        let host = NSHostingController(rootView: SettingsView(model: model))
        window = NSWindow(contentViewController: host)
        window.title = "MacOSWindowsLanguageChanger"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        refreshMenu()
        if !UserDefaults.standard.bool(forKey: "openedV271") {
            UserDefaults.standard.set(true, forKey: "openedV271")
            showSettings(nil)
        }
    }
    func refreshMenu() {
        guard item != nil, model != nil else { return }
        let appearance = model.appearance
        item.button?.image = appearance.image
        item.button?.imagePosition = .imageLeading
        let iconText = appearance.iconKind == 1 ? appearance.emojiLabel : ""
        let language = appearance.showLanguage ? (model.engine.remote ? "RDP" : model.engine.languageCode) : ""
        item.button?.title = [iconText, language].filter { !$0.isEmpty }.joined(separator: " ")
        if item.button?.image != nil && !language.isEmpty { item.button?.title = " " + language }
        item.button?.toolTip = model.status
        let menu = NSMenu()
        menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Настройки…", action: #selector(showSettings(_:)), keyEquivalent: ","); settings.target = self
        let pause = menu.addItem(withTitle: model.engine.enabled ? "Пауза" : "Продолжить", action: #selector(togglePause(_:)), keyEquivalent: ""); pause.target = self
        if !model.engine.remote {
            let sources = NSMenu()
            for source in model.engine.inputSources {
                guard let id = source["id"], let name = source["name"] else { continue }
                let row = sources.addItem(withTitle: name, action: #selector(selectSource(_:)), keyEquivalent: "")
                row.target = self; row.representedObject = id
                row.state = id == model.engine.currentSourceID ? .on : .off
            }
            let parent = menu.addItem(withTitle: "Раскладка", action: nil, keyEquivalent: "")
            parent.submenu = sources
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Завершить «MacOSWindowsLanguageChanger»", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
    }
    @objc func showSettings(_ sender: Any?) { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); model.recheck() }
    @objc func togglePause(_ sender: Any?) { model.engine.enabled.toggle() }
    @objc func selectSource(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { model.engine.selectSource(id) } }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(nil); return true }
}
@main
struct ApplicationEntry {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
