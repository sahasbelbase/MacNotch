#!/usr/bin/env bash
set -euo pipefail

echo "==> Building MacNotch Release binary..."
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -project MacNotch.xcodeproj -target MacNotch -configuration Release build

echo "==> Ensuring AppIcon is properly copied to bundle Resources..."
mkdir -p build/Release/MacNotch.app/Contents/Resources
cp SupportingFiles/AppIcon.icns build/Release/MacNotch.app/Contents/Resources/AppIcon.icns

echo "==> Signing MacNotch.app with stable Designated Requirement..."
codesign --force --deep --sign - \
         --entitlements SupportingFiles/MacNotch.entitlements \
         -r='designated => identifier "com.sahasbelbase.MacNotch"' \
         build/Release/MacNotch.app

codesign --verify --deep --strict build/Release/MacNotch.app

echo "==> Preparing DMG staging root..."
rm -rf build/dmg_root
mkdir -p build/dmg_root
cp -R build/Release/MacNotch.app build/dmg_root/
ln -s /Applications build/dmg_root/Applications

# Configure DMG custom volume icon
cp SupportingFiles/AppIcon.icns build/dmg_root/.VolumeIcon.icns
SetFile -c icnC build/dmg_root/.VolumeIcon.icns 2>/dev/null || true
SetFile -a C build/dmg_root 2>/dev/null || true

echo "==> Creating compressed disk image (MacNotch.dmg)..."
rm -f build/MacNotch.dmg MacNotch.dmg
hdiutil create -volname "MacNotch" \
               -srcfolder build/dmg_root \
               -ov \
               -format UDZO \
               build/MacNotch.dmg

cp build/MacNotch.dmg ./MacNotch.dmg
mkdir -p releases
cp build/MacNotch.dmg releases/MacNotch.dmg
echo "==> Done! Outputs:"
ls -lh MacNotch.dmg releases/MacNotch.dmg
