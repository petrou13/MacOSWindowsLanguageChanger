# MacOSWindowsLanguageChanger

**English** · [Русский](README.ru.md)

Switch your Mac's keyboard language like in Windows — with **Shift + Command**, without remapping Command or Option. A native menu-bar app for macOS users who want familiar language switching and working shortcuts in Windows App / Remote Desktop.

**[Download version 2.8](https://github.com/petrou13/MacOSWindowsLanguageChanger/releases/tag/v2.8)** · macOS 13+ · Apple Silicon and Intel · English and Russian interface

## Install

1. Download the **PKG** from Releases, open it and follow the standard macOS installer. It installs the app into Applications. Alternatively, unzip the ZIP and move the app into Applications yourself.
2. Launch MacOSWindowsLanguageChanger from Applications. Open Settings from its keyboard icon in the menu bar.
3. In **Switching**, select one access mode and click **Open permission settings…**. Enable the app in the matching macOS privacy list. Both permissions are not required together.
4. Return to the app. If macOS requires a restart after granting access, quit and reopen the app.

The app is locally signed (ad hoc); the PKG is unsigned. This preview is **not Developer ID signed or notarized by Apple**. macOS may block first opening. Follow [Apple's instructions](https://support.apple.com/102445); do not disable Gatekeeper.

## Features

- **Shift + Command**, **Option + Shift**, or **Control + Shift**. Hold either modifier, then the other, in any order. Switching happens after both are released; there is no hold-time threshold.
- An ordinary key, mouse click or scroll cancels the gesture. Existing shortcuts that include a letter keep their normal action. Command and Option are never remapped.
- Optional RDP exclusion, enabled by default. The switcher pauses while Windows App / Microsoft Remote Desktop is in the foreground and resumes when you focus another app.
- Immediate **English / Russian** interface selection in **General → Interface language**, saved between launches. The initial language follows macOS where supported, otherwise English. Changing the interface language does not switch the keyboard input source.
- Native SwiftUI settings grouped into Switching, Menu Bar, RDP, General and About. No startup permission dialogs. Inline access status and expandable shortcut diagnostics.
- Show or hide the current input source in the menu bar. Customize the icon with an SF Symbol, emoji or your own image. Light and Dark appearance, with a live preview.
- Optional launch at login using Apple's SMAppService.

## One mode, one permission

| Mode | Required permission | Switching method |
| --- | --- | --- |
| Input Monitoring — basic functionality | Input Monitoring | Selects the input source directly through TIS. The native indicator near the cursor may lag. |
| Accessibility — system shortcut | Accessibility | Sends the configured macOS input-source shortcut, including complete modifier presses and releases. |

System mode requires an enabled input-source selection shortcut in macOS keyboard settings. The app reads this assignment without changing system settings.

### RDP behavior

Exclusion is based on the **foreground app**, so it also includes local Windows App windows. It does not inspect individual remote sessions. While excluded, use the remote server's shortcut or Windows App settings to change the server's language. The app does not switch the server's input language for you. Turning exclusion off enables local switching inside Windows App; the remote result depends on the client's settings.

### Interface language and macOS labels

Choose the app language in General. Input-source names and standard macOS dialogs may follow the macOS system language. The app's settings, menu, status messages and diagnostic text follow your selected interface language.

## Privacy and verification

No network requests, telemetry, typed-text extraction or persistent key logs. The gesture recognizer tracks modifiers and a temporary set of held key codes to avoid triggering on ordinary shortcuts. Original input events are returned unchanged. Input-source updates use notifications and a short bounded refresh after switching, with no continuous polling.

Preferences and a thumbnail of your custom icon are stored locally. Imported images are limited to 10 MB, 8192 pixels per side and 32 megapixels. See [security checks and limitations](SECURITY.md).

Automated checks cover 60,000 gesture cycles, both key orders, ordinary typing cancellation, access-mode policy, malformed native shortcuts and 15 complete generated modifier combinations. English/Russian settings and immediate language changes were also checked in the running app. All macOS versions, text editors and live RDP sessions are not covered by these tests.

## License

**Personal and workplace use is permitted. Selling the app and paid redistribution are prohibited.** Free copying, modification and redistribution are permitted with the license and copyright notice preserved. The restriction also applies to modified versions and paid products or services that sell the app's functionality; ordinary paid work performed using the app as an internal tool is permitted.

See [LICENSE](LICENSE) for the complete bilingual terms. This is a custom source-available license, not an unrestricted open-source license. The English license text governs; the Russian text is a convenience translation. For a separate commercial distribution permission, contact the repository owner through GitHub.

## Build from source

Requires macOS, Xcode or Command Line Tools, and an accepted Apple toolchain license. There are no third-party dependencies.

```sh
chmod +x build.sh package.sh
./build.sh       # regression tests, localized universal app and ZIP in dist/
./package.sh     # standard macOS PKG installer and SHA-256 checksums
```

`APP_SIGNING_IDENTITY` selects a developer signing certificate; the default is ad hoc. Developer ID signing, installer signing and notarization remain separate distribution steps. The installer contains only the app, has no install scripts and uses the fixed Applications location.

Sources use SwiftUI/AppKit, Objective-C, Carbon and CoreGraphics. Localization uses native `.lproj` bundles and `.strings` resources shared by the Swift and Objective-C interface. The bundle identifier is preserved for compatibility with earlier preferences.

Apple references: [event access permissions](https://developer.apple.com/videos/play/wwdc2019/701/) · [macOS distribution](https://developer.apple.com/macos/distribution/).
