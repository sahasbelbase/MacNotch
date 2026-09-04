#!/usr/bin/env bash
set -euo pipefail

echo "==> Building MacNotch Release binary..."
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project MacNotch.xcodeproj -target MacNotch -configuration Release build

echo "==> Preparing DMG staging root..."
rm -rf build/dmg_root
mkdir -p build/dmg_root
cp -R build/Release/MacNotch.app build/dmg_root/
ln -s /Applications build/dmg_root/Applications

echo "==> Creating compressed disk image (MacNotch.dmg)..."
rm -f build/MacNotch.dmg MacNotch.dmg
hdiutil create -volname "MacNotch" \
               -srcfolder build/dmg_root \
               -ov \
               -format UDZO \
               build/MacNotch.dmg

cp build/MacNotch.dmg ./MacNotch.dmg
echo "==> Done! Output: ./MacNotch.dmg"
ls -lh MacNotch.dmg
