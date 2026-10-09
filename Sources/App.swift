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
    @Published var interfaceLanguage = WSInterfaceLanguage() {
        didSet {
            guard interfaceLanguage == "ru" || interfaceLanguage == "en" else { return }
            UserDefaults.standard.set(interfaceLanguage, forKey: "interfaceLanguage")
            appearance.error = ""
            engine.refreshLocalization()
        }
    }
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
    var accessModeName: String { engine.accessMode == 1 ? L("Универсальный доступ") : L("Мониторинг ввода") }
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
        if !engine.enabled { return L("Переключение на паузе") }
        if engine.remote { return L("RDP: клавиши без изменений") }
        if !engine.permitted { return LF("Разрешите %@", accessModeName) }
        if !engine.listening { return L("Мониторинг недоступен — проверьте разрешение") }
        return L("Готово к переключению")
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
                Text(L(title)).font(.title2.weight(.semibold))
                Text(L(subtitle)).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 6)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        TabView(selection: $model.tab) {
            switching.tabItem { Label(L("Переключение"), systemImage: "keyboard") }.tag(SettingsTab.switching)
            MenuAppearanceView(appearance: model.appearance).tabItem { Label(L("Строка меню"), systemImage: "menubar.rectangle") }.tag(SettingsTab.appearance)
            remote.tabItem { Label("RDP", systemImage: "desktopcomputer") }.tag(SettingsTab.remote)
            system.tabItem { Label(L("Основные"), systemImage: "gearshape") }.tag(SettingsTab.system)
            about.tabItem { Label(L("О приложении"), systemImage: "info.circle") }.tag(SettingsTab.about)
        }.padding(12).frame(width: 660, height: 600)
    }
    private var switching: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "keyboard", title: L("Привычное переключение языка"), subtitle: L("На Mac — как в Windows. Без переназначения клавиш."))
            Form {
                Section {
                    HStack {
                        Label(model.status, systemImage: model.engine.listening ? "checkmark.circle" : "circle.dashed")
                        Spacer()
                        Text(model.engine.languageCode).font(.headline.monospaced()).foregroundStyle(.secondary)
                    }
                    Toggle(L("Включить переключение"), isOn: Binding(get: { model.engine.enabled }, set: { model.engine.enabled = $0 }))
                    Picker(L("Сочетание"), selection: Binding(get: { model.engine.shortcut }, set: { model.engine.shortcut = $0 })) {
                        Text("⇧ Shift + ⌘ Command").tag(0)
                        Text("⌥ Option + ⇧ Shift").tag(1)
                        Text("⌃ Control + ⇧ Shift").tag(2)
                    }
                } header: { Text(L("Клавиши")) } footer: {
                    Text(L("Зажмите одну клавишу, затем вторую — в любом порядке. После отпускания обеих язык сменится. Ограничения по времени нет."))
                }
                switchingMode
                Section {
                    LabeledContent(L("Текущая раскладка"), value: model.engine.languageName)
                    TextField(L("Нажмите сочетание и напечатайте несколько букв"), text: $model.sample)
                        .textFieldStyle(.roundedBorder).accessibilityLabel(L("Проверка раскладки"))
                    HStack {
                        Button(L("Переключить сейчас")) { model.engine.switchLanguage() }
                        Spacer()
                        Button(L("Обновить")) { model.recheck() }
                    }
                    if !model.engine.message.isEmpty { Text(model.engine.message).foregroundStyle(.red) }
                    Button { model.diagnosticsShown.toggle() } label: {
                        HStack {
                            Image(systemName: model.diagnosticsShown ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold)).frame(width: 14)
                            Text(L("Диагностика сочетания"))
                            Spacer()
                        }.frame(maxWidth: .infinity, minHeight: 28, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityValue(model.diagnosticsShown ? L("Развёрнуто") : L("Свёрнуто"))
                    if model.diagnosticsShown {
                        Text(model.engine.diagnostic).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                } header: { Text(L("Проверка и диагностика")) } footer: {
                    Text(L("Сочетание с буквой, например Command + Shift + F, остаётся обычной горячей клавишей и не меняет язык."))
                }
            }.formStyle(.grouped)
        }
    }
    @ViewBuilder
    private var switchingMode: some View {
        Section {
            Picker(L("Режим доступа"), selection: Binding(get: { model.engine.accessMode }, set: { model.setAccessMode($0) })) {
                Text(L("Мониторинг ввода — базовый функционал")).tag(0)
                Text(L("Универсальный доступ — системное сочетание")).tag(1)
            }
            Text(model.engine.accessMode == 0 ? L("Прямая смена раскладки. Требуется только «Мониторинг ввода».") : L("Смена языка через штатное сочетание macOS. Требуется только «Универсальный доступ»."))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Label(model.engine.permitted ? L("Доступ предоставлен") : LF("Нет доступа: %@", model.accessModeName), systemImage: model.engine.permitted ? "checkmark.shield" : "exclamationmark.triangle")
                    .foregroundStyle(model.engine.permitted ? Color.secondary : Color.orange)
                Spacer()
                Button(L("Открыть настройки доступа…")) { model.openSelectedAccess() }
            }
            if !model.engine.permitted {
                Text(L("Включите приложение в соответствующем списке macOS. Если его нет, добавьте кнопкой «+»."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        } header: { Text(L("Способ переключения и доступ")) }
        Section {
            Label(L("Значок возле текстового курсора"), systemImage: "character.cursor.ibeam")
            Text(model.engine.systemSwitchStatus)
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.engine.accessMode == 1 {
                Button(L("Настроить системное сочетание…")) { model.keyboardSettings() }
            }
        } header: { Text(L("Индикация смены языка")) } footer: {
            Text(L("Встроенный значок рисует macOS. Отображение раскладки и значок приложения в строке меню настраиваются в разделе «Строка меню»."))
        }
    }
    private var remote: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "desktopcomputer", title: L("Горячие клавиши рабочего сервера"), subtitle: L("Поведение при активном окне Windows App или Microsoft Remote Desktop."))
            Form {
                Section {
                    Toggle(L("Отключать переключатель в RDP"), isOn: Binding(get: { model.engine.excludeRDP }, set: { model.engine.excludeRDP = $0 }))
                    Text(model.engine.excludeRDP ? L("В активном Windows App мониторинг и переключение выключены. После перехода в другое приложение переключатель снова работает.") : L("Переключатель работает и при активном Windows App. Он меняет раскладку на Mac; реакция удалённого сервера зависит от настроек клиента RDP."))
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } header: { Text(L("Поведение в RDP")) }
                Section {
                    LabeledContent(L("Command и Option"), value: L("Без переназначения"))
                    LabeledContent("Option + Shift + F", value: L("Без изменений"))
                    Text(L("Конечное действие сочетания определяется настройками Windows App и приложения на сервере."))
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } header: { Text(L("Сохранение сочетаний")) }
                Section {
                    Text(L("Если вы пользовались другой утилитой, отключите её и отмените сделанные ею переназначения модификаторов."))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("Открыть настройки клавиатуры…")) { model.keyboardSettings() }
                } header: { Text(L("После других утилит")) }
            }.formStyle(.grouped)
        }
    }
    private var system: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "gearshape", title: L("Поведение приложения"), subtitle: L("Автозапуск, язык интерфейса и приватность."))
            Form {
                Section {
                    Picker(L("Язык интерфейса"), selection: $model.interfaceLanguage) {
                        Text("Русский").tag("ru")
                        Text("English").tag("en")
                    }
                } header: { Text(L("Язык интерфейса")) } footer: {
                    Text(L("Изменение применяется сразу и не меняет раскладку клавиатуры."))
                }
                Section {
                    Toggle(L("Запускать при входе в macOS"), isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    if !model.loginMessage.isEmpty { Text(model.loginMessage).foregroundStyle(.red) }
                } header: { Text(L("Автозапуск")) } footer: {
                    Text(L("Храните приложение в постоянном месте, например в папке «Программы»."))
                }
                Section {
                    Label(L("Введённый текст не сохраняется"), systemImage: "lock")
                    Label(L("Сетевые запросы не выполняются"), systemImage: "network.slash")
                    DisclosureGroup(L("Как уменьшается нагрузка")) {
                        Text(L("Один наблюдатель событий без постоянного опроса. Он распознаёт модификаторы и факт добавления другой клавиши, не сохраняя текст. После смены языка выполняется короткая серия обновлений индикатора. На паузе и в RDP при включённом исключении мониторинг выключен."))
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
                    }
                } header: { Text(L("Приватность")) }
            }.formStyle(.grouped)
        }
    }
    private var about: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage()).resizable().frame(width: 76, height: 76).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("MacOSWindowsLanguageChanger").font(.title2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                    Text(L("Переключение языка как в Windows для macOS")).foregroundStyle(.secondary)
                    Text(L("Версия 2.8 · macOS 13 и новее")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Form {
                Section {
                    Text(L("Переключение языка на Mac через Shift + Command, Option + Shift или Control + Shift. Исключение для Windows App настраивается на вкладке RDP."))
                        .fixedSize(horizontal: false, vertical: true)
                } header: { Text(L("Для чего приложение")) }
                Section {
                    Text(L("Личное и рабочее использование разрешено. Продажа и платное распространение приложения запрещены."))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L("Открыть условия лицензии…")) {
                        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } header: { Text(L("Лицензия")) }
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
        if !UserDefaults.standard.bool(forKey: "openedV28") {
            UserDefaults.standard.set(true, forKey: "openedV28")
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
        let settings = menu.addItem(withTitle: L("Настройки…"), action: #selector(showSettings(_:)), keyEquivalent: ","); settings.target = self
        let pause = menu.addItem(withTitle: model.engine.enabled ? L("Пауза") : L("Продолжить"), action: #selector(togglePause(_:)), keyEquivalent: ""); pause.target = self
        if !model.engine.remote {
            let sources = NSMenu()
            for source in model.engine.inputSources {
                guard let id = source["id"], let name = source["name"] else { continue }
                let row = sources.addItem(withTitle: name, action: #selector(selectSource(_:)), keyEquivalent: "")
                row.target = self; row.representedObject = id
                row.state = id == model.engine.currentSourceID ? .on : .off
            }
            let parent = menu.addItem(withTitle: L("Раскладка"), action: nil, keyEquivalent: "")
            parent.submenu = sources
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Завершить «MacOSWindowsLanguageChanger»"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
