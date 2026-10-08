#!/bin/zsh
set -eu
cd "${0:A:h}"
if [[ -x /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc ]]; then
  toolchain=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
  sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
else
  toolchain=$(dirname "$(xcrun --find swiftc)")
  sdk=$(xcrun --sdk macosx --show-sdk-path)
fi
mkdir -p .build dist
scratch="${PWD}/.build"
"$toolchain/clang" -isysroot "$sdk" -Wall -Wextra -Werror Tests/chord_test.c -o "$scratch/chord-tests"
"$scratch/chord-tests"
"$toolchain/clang" -isysroot "$sdk" -fobjc-arc -Wall -Wextra -Werror Tests/native_shortcut_test.m -framework Foundation -framework ApplicationServices -o "$scratch/native-shortcut-tests"
"$scratch/native-shortcut-tests"
"$toolchain/swiftc" -module-cache-path "$scratch/ModuleCache" -sdk "$sdk" Tools/Icon.swift -o "$scratch/icon-maker"
"$scratch/icon-maker" "$scratch/AppIcon.iconset"
app='dist/MacOSWindowsLanguageChanger.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
  "$toolchain/clang" -isysroot "$sdk" -arch "$arch" -mmacosx-version-min=13.0 -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Werror -c Sources/Engine.m -o "$scratch/Engine-$arch.o"
  "$toolchain/swiftc" -module-cache-path "$scratch/ModuleCache" -sdk "$sdk" -target "$arch-apple-macosx13.0" -import-objc-header Sources/Engine.h Sources/App.swift Sources/MenuAppearance.swift "$scratch/Engine-$arch.o" -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement -o "$scratch/KeyboardLanguage-$arch"
done
"$toolchain/lipo" -create "$scratch/KeyboardLanguage-arm64" "$scratch/KeyboardLanguage-x86_64" -output "$app/Contents/MacOS/KeyboardLanguage"
cp "$scratch/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$scratch/AppIcon.iconset/icon_512x512@2x.png" dist/Icon-Dark.png
cp "$scratch/Icon-Light.png" dist/Icon-Light.png
cp "$scratch/AppIcon-Light.icns" "$app/Contents/Resources/AppIcon-Light.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KeyboardLanguage</string>
<key>CFBundleIdentifier</key><string>local.maloypictures.WinSwitch</string>
<key>CFBundleName</key><string>MacOSWindowsLanguageChanger</string>
<key>CFBundleDisplayName</key><string>MacOSWindowsLanguageChanger</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.7.1</string>
<key>CFBundleVersion</key><string>10</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>Распознавание модификаторов для переключения языка. Текст не сохраняется.</string>
</dict></plist>
PLIST
signingIdentity="${APP_SIGNING_IDENTITY:--}"
timestampOption=--timestamp
[[ "$signingIdentity" == - ]] && timestampOption=--timestamp=none
/usr/bin/codesign --force --sign "$signingIdentity" --options runtime "$timestampOption" --identifier local.maloypictures.WinSwitch "$app"
/usr/bin/codesign --verify --strict "$app"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/ditto --norsrc -c -k --keepParent "$app" dist/MacOSWindowsLanguageChanger-2.7.1-macOS-universal.zip
print "Built: ${PWD}/$app"
