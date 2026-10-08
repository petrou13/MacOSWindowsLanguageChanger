import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

final class MenuAppearance: ObservableObject {
    @Published var showLanguage: Bool { didSet { save() } }
    @Published var iconKind: Int { didSet { save() } }
    @Published var symbol: String { didSet { save() } }
    @Published var emoji: String { didSet { save() } }
    @Published var templateImage: Bool { didSet { save() } }
    @Published var imageData: Data? { didSet { save() } }
    @Published var imageName: String { didSet { save() } }
    @Published var error = ""
    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["menuShowLanguage": true, "menuIconKind": 0, "menuSymbol": "keyboard", "menuEmoji": "⌨️", "menuTemplateImage": false])
        showLanguage = defaults.bool(forKey: "menuShowLanguage")
        iconKind = defaults.integer(forKey: "menuIconKind")
        symbol = defaults.string(forKey: "menuSymbol") ?? "keyboard"
        emoji = defaults.string(forKey: "menuEmoji") ?? "⌨️"
        templateImage = defaults.bool(forKey: "menuTemplateImage")
        imageData = defaults.data(forKey: "menuImageData")
        imageName = defaults.string(forKey: "menuImageName") ?? ""
    }
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(showLanguage, forKey: "menuShowLanguage")
        defaults.set(iconKind, forKey: "menuIconKind")
        defaults.set(symbol, forKey: "menuSymbol")
        defaults.set(emoji, forKey: "menuEmoji")
        defaults.set(templateImage, forKey: "menuTemplateImage")
        defaults.set(imageData, forKey: "menuImageData")
        defaults.set(imageName, forKey: "menuImageName")
        NotificationCenter.default.post(name: Notification.Name("LanguageMenuRefresh"), object: nil)
    }
    var image: NSImage? {
        if iconKind == 1 { return nil }
        if iconKind == 2, let data = imageData, let image = NSImage(data: data) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = templateImage
            return image
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
    var emojiLabel: String { String(emoji.prefix(1)).isEmpty ? "⌨️" : String(emoji.prefix(1)) }
    func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "Выберите значок для строки меню"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 10_000_000 else { error = "Выберите изображение размером до 10 МБ."; return }
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.doubleValue > 0, height.doubleValue > 0,
                  width.doubleValue <= 8192, height.doubleValue <= 8192,
                  width.doubleValue * height.doubleValue <= 32_000_000,
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 36,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary),
                  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: bitmap) else { error = "Не удалось прочитать изображение. Выберите PNG или JPEG до 8192 пикселей и 32 мегапикселей."; return }
            let source = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            NSColor.clear.setFill()
            NSRect(x: 0, y: 0, width: 36, height: 36).fill(using: .copy)
            let ratio = min(36 / source.size.width, 36 / source.size.height)
            let size = NSSize(width: source.size.width * ratio, height: source.size.height * ratio)
            source.draw(in: NSRect(x: (36-size.width)/2, y: (36-size.height)/2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            guard let data = bitmap.representation(using: .png, properties: [:]) else { error = "Не удалось сохранить значок."; return }
            imageData = data
            imageName = url.lastPathComponent
            iconKind = 2
            error = ""
        } catch { self.error = "Не удалось открыть файл: \(error.localizedDescription)" }
    }
    func reset() {
        showLanguage = true; iconKind = 0; symbol = "keyboard"; emoji = "⌨️"
        templateImage = false; imageData = nil; imageName = ""; error = ""
    }
}

struct MenuAppearanceView: View {
    @ObservedObject var appearance: MenuAppearance
    private let symbols = [("keyboard", "Клавиатура"), ("globe", "Глобус"), ("character.bubble", "Язык"), ("command", "Command"), ("arrow.triangle.2.circlepath", "Переключение")]
    var body: some View {
        VStack(spacing: 0) {
            PageIntro(symbol: "menubar.rectangle", title: "Отображение в строке меню", subtitle: "Раскладка, значок и предпросмотр. Изменения применяются сразу.")
            Form {
                Section {
                    Toggle("Показывать текущую раскладку", isOn: $appearance.showLanguage)
                    Text("Если выключено, остаётся только выбранный значок. Доступ к меню приложения сохраняется.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } header: { Text("Раскладка в строке меню") }
                Section {
                    Picker("Тип значка", selection: $appearance.iconKind) {
                        Text("Системный символ").tag(0)
                        Text("Эмодзи").tag(1)
                        Text("Изображение из файла").tag(2)
                    }
                    if appearance.iconKind == 0 {
                        HStack {
                            ForEach(symbols, id: \.0) { symbol, title in
                                Button { appearance.symbol = symbol } label: {
                                    Image(systemName: symbol).frame(width: 28, height: 24)
                                }.help(title).accessibilityLabel(title)
                            }
                        }
                        TextField("Имя любого SF Symbol", text: $appearance.symbol).textFieldStyle(.roundedBorder)
                        if NSImage(systemSymbolName: appearance.symbol, accessibilityDescription: nil) == nil {
                            Text("Такой символ не найден. Пока отображается клавиатура.").font(.caption).foregroundStyle(.orange)
                        }
                    } else if appearance.iconKind == 1 {
                        TextField("Эмодзи", text: $appearance.emoji).textFieldStyle(.roundedBorder)
                        Text("Откройте выбор эмодзи через Control + Command + пробел. Используется первый символ.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Button("Выбрать изображение…") { appearance.chooseImage() }
                        if !appearance.imageName.isEmpty { Text(appearance.imageName).font(.caption).foregroundStyle(.secondary) }
                        Toggle("Адаптировать цвет к светлой и тёмной теме", isOn: $appearance.templateImage)
                        Text("Для одноцветных значков включите адаптацию. Для цветных изображений оставьте её выключенной. Файл копируется в настройки; оригинал больше не нужен.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if !appearance.error.isEmpty { Text(appearance.error).foregroundStyle(.red) }
                } header: { Text("Значок") }
                Section {
                    HStack {
                        Text("Предпросмотр")
                        Spacer()
                        if let image = appearance.image { Image(nsImage: image).resizable().scaledToFit().frame(width: 18, height: 18) }
                        else { Text(appearance.emojiLabel) }
                        if appearance.showLanguage { Text("EN").font(.body.monospaced()) }
                    }.padding(.vertical, 4)
                    Button("Вернуть стандартный вид") { appearance.reset() }
                } header: { Text("Как это выглядит") }
            }.formStyle(.grouped)
        }
    }
}
