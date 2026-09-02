#!/bin/bash
# ============================================================
#  yakusoku · iOS IPA 构建脚本（必须在 macOS + Xcode 上运行）
#
#  用法:
#    TEAM_ID=XXXXXXXXXX ./build-ipa.sh            # 自动签名（免费账号，7 天有效）
#    P12_PATH=cert.p12 P12_PASSWORD=xxx \
#    PROVISION=app.mobileprovision TEAM_ID=XXXX \
#    EXPORT_METHOD=ad-hoc ./build-ipa.sh          # 证书签名（可长期 / 上架）
#    ./build-ipa.sh unsigned                      # 不签名（仅越狱机 / 云构建产物）
#
#  前置: brew install xcodegen
# ============================================================
set -euo pipefail

MODE="${1:-unsigned}"
PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJ_DIR"

APP_NAME="yakusoku"
BUNDLE_ID="com.yakusoku.app"
SCHEME="Yakusoku"
BUILD_DIR="$PROJ_DIR/build"
ARCHIVE="$BUILD_DIR/Yakusoku.xcarchive"
EXPORT_DIR="$BUILD_DIR/ipa-export"

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[1;33m'; NC=$'\033[0m'
log()  { echo -e "${GRN}[✓]${NC} $1"; }
warn() { echo -e "${YEL}[!]${NC} $1"; }
die()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo "=========================================="
echo " yakusoku iOS 构建"
echo " App: $APP_NAME   BundleID: $BUNDLE_ID"
echo " 模式: ${MODE}"
echo "=========================================="

# ---- 0. 环境检查 ----
[ "$(uname -s)" = "Darwin" ] || die "必须在 macOS 上运行（当前: $(uname -s)）。"
command -v xcodebuild >/dev/null || die "未找到 xcodebuild，请先安装 Xcode"
log "Xcode: $(xcodebuild -version | head -1)"

# ---- 1. 生成 Xcode 工程 ----
echo ""
echo ">> [1/4] 生成 Xcode 工程"
command -v xcodegen >/dev/null || die "未找到 xcodegen，请先执行: brew install xcodegen"
xcodegen --spec project.yml
log "Yakusoku.xcodeproj 已生成"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ---- 2. Archive ----
echo ""
echo ">> [2/4] 编译 Archive"
case "$MODE" in
  auto)
    [ -n "${TEAM_ID:-}" ] || die "auto 模式需 TEAM_ID。查询: developer.apple.com → Membership → Team ID"
    xcodebuild -project Yakusoku.xcodeproj -scheme "$SCHEME" \
      -sdk iphoneos -configuration Release \
      -archivePath "$ARCHIVE" archive \
      -allowProvisioningUpdates \
      DEVELOPMENT_TEAM="$TEAM_ID" \
      PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
      CODE_SIGN_STYLE=Automatic 2>&1 | tail -25
    cat > "$BUILD_DIR/ExportOptions.plist" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>development</string>
<key>teamID</key><string>${TEAM_ID}</string>
<key>signingStyle</key><string>automatic</string>
<key>compileBitcode</key><false/>
</dict></plist>
PEOF
    ;;
  cert)
    [ -n "${P12_PATH:-}" ] || die "cert 模式需: P12_PATH=... P12_PASSWORD=... PROVISION=..."
    KS="$BUILD_DIR/ios-build.keychain"; KSPW="tmp-$(date +%s)"
    security create-keychain -p "$KSPW" "$KS" 2>/dev/null
    security unlock-keychain -p "$KSPW" "$KS"
    security import "$P12_PATH" -k "$KS" -P "${P12_PASSWORD}" -T /usr/bin/codesign -T /usr/bin/xcodebuild 2>&1 | tail -1
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KSPW" "$KS" >/dev/null
    security list-keychains -d user -s "$KS" $(security list-keychains -d user | tr -d '"')
    security default-keychain -s "$KS"
    xcodebuild -project Yakusoku.xcodeproj -scheme "$SCHEME" \
      -sdk iphoneos -configuration Release \
      -archivePath "$ARCHIVE" archive \
      CODE_SIGN_STYLE=Manual \
      DEVELOPMENT_TEAM="${TEAM_ID:-}" \
      PROVISIONING_PROFILE_SPECIFIER="${PROVISION}" 2>&1 | tail -25
    cat > "$BUILD_DIR/ExportOptions.plist" <<PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>${EXPORT_METHOD:-ad-hoc}</string>
<key>teamID</key><string>${TEAM_ID:-}</string>
<key>signingStyle</key><string>manual</string>
<key>compileBitcode</key><false/>
</dict></plist>
PEOF
    ;;
  unsigned|*)
    log "未签名模式（unsigned）：跳过签名"
    xcodebuild -project Yakusoku.xcodeproj -scheme "$SCHEME" \
      -sdk iphoneos -configuration Release \
      -archivePath "$ARCHIVE" archive \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO 2>&1 | tail -25
    ;;
esac
[ -d "$ARCHIVE" ] || die "Archive 失败，请查看上方编译错误"
log "Archive 生成完毕"

# ---- 3. 导出 / 打包 IPA ----
echo ""
echo ">> [3/4] 打包 IPA"
if [ "$MODE" = "unsigned" ] || [ "$MODE" = "nosign" ]; then
  APP_SRC="$ARCHIVE/Products/Applications/Yakusoku.app"
  [ -d "$APP_SRC" ] || APP_SRC="$ARCHIVE/Products/Applications/yakusoku.app"
  [ -d "$APP_SRC" ] || die "在 Archive 中找不到 .app"
  mkdir -p "$BUILD_DIR/Payload"
  cp -R "$APP_SRC" "$BUILD_DIR/Payload/"
  (cd "$BUILD_DIR" && zip -qry "${APP_NAME}.ipa" Payload)
  IPA="$BUILD_DIR/${APP_NAME}.ipa"
else
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" 2>&1 | tail -10
  IPA=$(find "$EXPORT_DIR" -name "*.ipa" | head -1)
  [ -n "$IPA" ] || die "导出 IPA 失败"
  cp "$IPA" "$BUILD_DIR/${APP_NAME}.ipa"
  IPA="$BUILD_DIR/${APP_NAME}.ipa"
fi

# ---- 4. 校验 ----
echo ""
echo ">> [4/4] 校验产物"
echo "  IPA: $IPA"
echo "  大小: $(du -h "$IPA" | cut -f1)"
unzip -l "$IPA" >/dev/null 2>&1 && log "IPA 结构完好"

echo ""
echo "=========================================="
if [ "$MODE" = "unsigned" ]; then
  warn "未签名 IPA：仅可用 AltStore / Sideloadly / 越狱设备安装。"
  warn "上架需在 macOS 用 auto/cert 模式重签（需 Apple 开发者账号）。"
else
  log "签名模式 ${MODE} 构建完成"
fi
echo "=========================================="
