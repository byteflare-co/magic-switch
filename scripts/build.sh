#!/bin/bash
# scripts/build.sh - アプリケーションバンドルのビルド

set -euo pipefail

APP_NAME="MagicSwitch"
BUNDLE_ID="com.magicswitch.app"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "=== Building ${APP_NAME} v${VERSION} ==="

# 1. Swift Package Manager でリリースビルド
swift build -c release

# 2. .app バンドル構造の作成
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. 実行ファイルの配置
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 4. blueutil バイナリの配置（存在する場合）
if [ -f "Resources/blueutil" ]; then
    cp "Resources/blueutil" "${APP_BUNDLE}/Contents/Resources/"
    chmod +x "${APP_BUNDLE}/Contents/Resources/blueutil"
fi

# 5. Info.plist の配置
if [ -f "Resources/Info.plist" ]; then
    cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/"
else
    cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Magic Switch はデバイスの検出・接続切り替えに Bluetooth を使用します。</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Magic Switch は Mac 間でデバイス切り替えコマンドを送受信するためにローカルネットワークを使用します。</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_blueswitch._tcp.</string>
    </array>
</dict>
</plist>
PLIST
fi

# 6. エンタイトルメント
cat > "${BUILD_DIR}/entitlements.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.bluetooth</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
PLIST

# 7. ad-hoc 署名（リンカー署名を上書きして正しい署名にする）
# これにより Gatekeeper が「壊れている」ではなく「開発元を確認できません」と表示する
echo "Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# 署名検証
codesign --verify --deep --strict "${APP_BUNDLE}" && echo "Signature OK" || echo "WARNING: Signature verification failed"

echo "=== Build complete: ${APP_BUNDLE} ==="
echo "To run: open ${APP_BUNDLE}"
