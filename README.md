# MacOSWindowsLanguageChanger

Windows-style keyboard language switching for macOS, with **Shift + Command**, without remapping Command or Option. A native SwiftUI menu-bar app for people who need familiar language switching and working shortcuts in Windows App / Remote Desktop.

**[Download the macOS installer](https://github.com/petrou13/MacOSWindowsLanguageChanger/releases)** · macOS 13+ · Apple Silicon and Intel

## Установка

1. Скачайте PKG из Releases, откройте его и следуйте шагам стандартного установщика macOS. Он установит приложение в Applications («Программы»).
2. Запустите MacOSWindowsLanguageChanger из «Программ». Альтернатива без установщика: распакуйте ZIP и перетащите приложение в «Программы».
3. Откройте настройки через значок клавиатуры в строке меню. В разделе «Переключение» выберите один режим доступа и нажмите «Открыть настройки доступа…».
4. Разрешите выбранный доступ в macOS и вернитесь в приложение. Если macOS требует перезапуск, завершите и снова откройте приложение.

Версия 2.7.1 подписана локально (ad hoc), **без Developer ID и нотарификации Apple**. При блокировке первого запуска используйте [официальную инструкцию Apple](https://support.apple.com/102445). Не отключайте Gatekeeper.

## Возможности

- Shift + Command, Option + Shift или Control + Shift. Можно зажать первую клавишу и затем вторую в любом порядке. Переключение происходит после отпускания обеих; ограничения по длительности нет.
- Обычная клавиша, щелчок или прокрутка отменяет сочетание. Command и Option не переназначаются.
- Настраиваемое отключение в Windows App / Microsoft Remote Desktop, включённое по умолчанию. Пауза действует, пока приложение RDP на переднем плане; при переходе в другое приложение переключение возобновляется.
- Настройки индикации смены языка, диагностика, запуск при входе в macOS.
- Текущую раскладку в строке меню можно скрыть. Значок: SF Symbol, эмодзи или своё изображение. Светлая и тёмная темы.
- При запуске нет навязчивых запросов разрешений. Состояние доступа видно в настройках.

## Один режим — одно разрешение

| Режим | Разрешение | Как переключает |
| --- | --- | --- |
| Мониторинг ввода — базовый функционал | Мониторинг ввода | Напрямую выбирает источник ввода через TIS. Системный значок у курсора может отставать. |
| Универсальный доступ — вывод системного сочетания | Универсальный доступ | Отправляет настроенное системное сочетание выбора источника ввода с полным нажатием и отпусканием модификаторов. |

Одновременно оба разрешения не нужны. Для системного режима должно быть включено сочетание выбора источника ввода в настройках клавиатуры macOS. Параметры системных сочетаний приложение только читает.

При исключении RDP приложение не меняет язык на сервере: используйте серверное сочетание или настройки Windows App. Исключение определяется по активному приложению, поэтому включает и локальные окна Windows App. Работа внутри конкретного удалённого сеанса отдельно не определяется.

## Privacy / безопасность

Нет сетевых запросов, телеметрии, записи текста или нажатий на диск. Для распознавания сочетания нужен обработчик событий: он учитывает модификаторы и временный набор кодов удерживаемых клавиш, чтобы обычные горячие клавиши не переключали язык. Исходные события возвращаются без изменений. Проверки раскладки выполняются по уведомлениям и короткой ограниченной серии обновлений после переключения, без постоянного опроса.

Настройки и уменьшенная копия выбранного значка сохраняются локально в UserDefaults. Подробнее о проверках и ограничениях: [SECURITY.md](SECURITY.md).

## Build

Requires macOS with Xcode or the Command Line Tools and an accepted Apple toolchain license.

```sh
chmod +x build.sh package.sh
./build.sh       # regression tests + universal app and ZIP in dist/
./package.sh     # additionally creates the standard macOS installation PKG
```

No third-party dependencies. `APP_SIGNING_IDENTITY` can select a developer signing certificate; the default is an ad-hoc signature. Developer ID signing and notarization are separate distribution steps and are not performed automatically.

Sources: SwiftUI/AppKit for settings and menu bar; Objective-C/Carbon/CoreGraphics for input source and gesture handling. The bundle identifier is preserved for settings compatibility with earlier versions.

Apple references: [event access permissions](https://developer.apple.com/videos/play/wwdc2019/701/), [macOS distribution](https://developer.apple.com/macos/distribution/).
