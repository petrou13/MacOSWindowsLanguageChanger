#!/bin/zsh
set -eu
cd "${0:A:h}"
./build.sh
/usr/bin/pkgbuild --analyze --component dist/MacOSWindowsLanguageChanger.app .build/components.plist
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' .build/components.plist
/usr/bin/pkgbuild --component dist/MacOSWindowsLanguageChanger.app --component-plist .build/components.plist --install-location /Applications --identifier local.maloypictures.WinSwitch.installer --version 2.7.1 dist/MacOSWindowsLanguageChanger-2.7.1-macOS-universal.pkg
cd dist
/usr/bin/shasum -a 256 MacOSWindowsLanguageChanger-2.7.1-macOS-universal.pkg MacOSWindowsLanguageChanger-2.7.1-macOS-universal.zip > SHA256SUMS.txt
