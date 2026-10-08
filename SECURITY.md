# Security and verification — 2.7.1

This is a public preview. Review and regression testing reduce risk but do not certify the application as free from defects.

## Scope

- No network clients, telemetry, subprocess execution, downloaded code, or automatic updates in the app.
- No text extraction or persistent key logs. Transient key codes are used only to cancel incomplete language gestures when another key is held. Diagnostic counters and the last gesture status remain in memory.
- Basic mode uses a passive event tap; system mode uses an Accessibility-authorized tap that returns every original event unchanged. Only an intentional language-switch gesture or explicit switch button sends the configured native input-source shortcut.
- Generated modifiers include matching releases. Physical modifiers and foreground application are checked before sending. Focus changes, pause, mode changes, and sleep cancel pending native targets.
- RDP protection is optional and defaults on. It is based on the foreground application's bundle identifier. Turning it off allows local switching while RDP is active.
- Imported icons are limited to 10 MB, 8192 pixels on either side and 32 megapixels. ImageIO creates a thumbnail before rendering a 36×36 PNG. Only the thumbnail is retained.
- Access is never granted by the app itself. Permission settings open only after the user's explicit action. No startup permission dialogs.
- Login registration uses Apple's SMAppService and is opt-in.

## Checks performed

- Universal arm64 / x86_64 build, deployment target macOS 13; strict compiler warnings for Objective-C and C tests.
- 60,000 gesture cycles including both modifier orders, ordinary typing cancellation and no timing threshold.
- Native shortcut parsing: custom assignments, ordering, disabled/malformed entries, modifier and Power key rejection.
- 15 modifier combinations: complete generated event lifecycle and preservation of Caps Lock, without posting input during tests.
- Access policy tests: each mode requires only its own permission.
- Code signature and installer payload verification. The PKG installs only the app into /Applications, without installer scripts, and cannot relocate to an older copy elsewhere. SHA-256 checksums are published alongside the installer.

## Limits

The public build is ad-hoc signed, not Developer ID signed or notarized. Gatekeeper may block first launch. Do not disable macOS security protections. Input permissions depend on macOS identity/path and may need to be granted again after installation or updating an ad-hoc build.

Basic switching was confirmed with actual text input during development. Full physical Shift+Command testing in every application, all macOS versions, and a live working-server RDP session is not covered by automated tests. Native cursor-accessory behavior depends on macOS and the focused text editor. The basic mode can leave that accessory stale; use the system mode for native indication.

Report reproducible non-sensitive defects through repository Issues. Do not upload passwords, typed work content, private server addresses or screenshots with confidential information.
