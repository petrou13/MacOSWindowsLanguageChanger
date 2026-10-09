#!/bin/zsh
set -eu
cd "${0:A:h}"
./build.sh
mkdir -p .build/package-root
/usr/bin/ditto --norsrc dist/MacOSWindowsLanguageChanger.app .build/package-root/MacOSWindowsLanguageChanger.app
/usr/bin/pkgbuild --analyze --root .build/package-root .build/components.plist
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' .build/components.plist
/usr/bin/pkgbuild --root .build/package-root --component-plist .build/components.plist --install-location /Applications --identifier local.maloypictures.WinSwitch.installer --version 2.8 dist/MacOSWindowsLanguageChanger-2.8-macOS-universal.pkg
cd dist
/usr/bin/shasum -a 256 MacOSWindowsLanguageChanger-2.8-macOS-universal.pkg MacOSWindowsLanguageChanger-2.8-macOS-universal.zip > SHA256SUMS.txt
