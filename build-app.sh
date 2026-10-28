#!/bin/bash
# Construit Flocon.app et l'installe dans ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/Flocon.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Flocon "$APP/Contents/MacOS/Flocon"

# Icône : un PNG dessiné par script, décliné dans toutes les tailles que macOS attend.
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
swift scripts/make-icon.swift build/icon.png
for s in 16 32 128 256 512; do
    sips -z $s $s build/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) build/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Flocon</string>
    <key>CFBundleIdentifier</key><string>fr.perso.flocon</string>
    <key>CFBundleExecutable</key><string>Flocon</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# Un certificat stable garde l'autorisation Accessibilité d'une version à l'autre ;
# sans lui, la signature locale change à chaque build et macOS oublie l'autorisation.
if security find-identity -p codesigning | grep -q "Flocon Dev"; then
    codesign --force --sign "Flocon Dev" "$APP"
else
    codesign --force --sign - "$APP"
fi

mkdir -p ~/Applications
rm -rf ~/Applications/Flocon.app
cp -R "$APP" ~/Applications/
echo "Installé : ~/Applications/Flocon.app"
