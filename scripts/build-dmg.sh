#!/usr/bin/env bash
#
# build-dmg.sh — Archive、导出 .app、打包 .dmg
#
# 用法：
#   ./scripts/build-dmg.sh              # 默认 Release
#   ./scripts/build-dmg.sh --debug      # Debug 构建
#
set -euo pipefail

# ── 配置 ──────────────────────────────────────────────
APP_NAME="MenuBarHubApp"
SCHEME="MenuBarHubApp"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="${PROJECT_DIR}/${APP_NAME}.xcodeproj"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
DMG_OUTPUT="${BUILD_DIR}/${APP_NAME}.dmg"
CONFIGURATION="Release"

if [[ "${1:-}" == "--debug" ]]; then
    CONFIGURATION="Debug"
fi

# ── 清理 ──────────────────────────────────────────────
echo "==> 清理旧构建产物..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ── Archive ───────────────────────────────────────────
echo "==> Archive (${CONFIGURATION})..."
xcodebuild archive \
    -project "${XCODEPROJ}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -quiet

echo "    Archive 完成: ${ARCHIVE_PATH}"

# ── 导出 .app ─────────────────────────────────────────
echo "==> 导出 .app..."

# 生成 ExportOptions.plist（Developer ID 签名，不上传 notarization）
EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"
cat > "${EXPORT_OPTIONS}" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

# 尝试 exportArchive；如果签名不满足（比如没有 Developer ID），回退到直接拷贝
if xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -quiet 2>/dev/null; then
    echo "    导出完成 (exportArchive)"
else
    echo "    exportArchive 失败，回退到直接拷贝 .app..."
    mkdir -p "${EXPORT_DIR}"
    cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${EXPORT_DIR}/"
fi

APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "错误：找不到 ${APP_PATH}"
    exit 1
fi

echo "    .app 路径: ${APP_PATH}"

# ── 打包 .dmg ─────────────────────────────────────────
echo "==> 打包 .dmg..."

if command -v create-dmg &>/dev/null; then
    # ── create-dmg（brew install create-dmg）──
    echo "    使用 create-dmg..."
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 128 \
        --icon "${APP_NAME}.app" 150 185 \
        --app-drop-link 450 185 \
        --no-internet-enable \
        "${DMG_OUTPUT}" \
        "${APP_PATH}" \
    || {
        # create-dmg 在没有 AppIcon.icns 时会失败，去掉 --volicon 重试
        echo "    重试（不含 volicon）..."
        create-dmg \
            --volname "${APP_NAME}" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 128 \
            --icon "${APP_NAME}.app" 150 185 \
            --app-drop-link 450 185 \
            --no-internet-enable \
            "${DMG_OUTPUT}" \
            "${APP_PATH}"
    }
else
    # ── hdiutil 原生方式 ──
    echo "    create-dmg 未安装，使用 hdiutil..."
    STAGING="${BUILD_DIR}/dmg-staging"
    mkdir -p "${STAGING}"
    cp -R "${APP_PATH}" "${STAGING}/"

    # 创建指向 /Applications 的符号链接
    ln -s /Applications "${STAGING}/Applications"

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${STAGING}" \
        -ov -format UDZO \
        "${DMG_OUTPUT}"

    rm -rf "${STAGING}"
fi

echo ""
echo "==> 完成！"
echo "    DMG: ${DMG_OUTPUT}"
echo "    大小: $(du -h "${DMG_OUTPUT}" | cut -f1)"
