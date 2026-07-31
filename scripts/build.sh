#!/bin/bash
# OnomatopeCursor ビルド & 配布パッケージ作成
#   ./scripts/build.sh          → build/OnomatopeCursor.app と dist/OnomatopeCursor-<ver>.zip
# 必要なもの: Xcode Command Line Tools (xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
APP=build/OnomatopeCursor.app

echo "==> OnomatopeCursor v$VERSION をビルド"
rm -rf build dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist

echo "==> テスト実行"
swift run -c release onomatope-tests

# ユニバーサルバイナリ（Apple Silicon + Intel）。--arch同時指定はXcode必須のためtriple別+lipo
swift build -c release --triple arm64-apple-macosx12.0 --product OnomatopeCursor
swift build -c release --triple x86_64-apple-macosx12.0 --product OnomatopeCursor
lipo -create .build/arm64-apple-macosx/release/OnomatopeCursor \
             .build/x86_64-apple-macosx/release/OnomatopeCursor \
     -output "$APP/Contents/MacOS/OnomatopeCursor"
sed "s/__VERSION__/$VERSION/g" packaging/Info.plist > "$APP/Contents/Info.plist"

# アイコン生成（キャッシュがあれば再利用）
if [ ! -f packaging/AppIcon.icns ]; then
  echo "==> アイコン生成"
  ICONDIR=build/AppIcon.iconset
  mkdir -p "$ICONDIR"
  swift scripts/make_icon.swift build/icon_1024.png
  for sz in 16 32 128 256 512; do
    sips -z $sz $sz build/icon_1024.png --out "$ICONDIR/icon_${sz}x${sz}.png" >/dev/null
    sips -z $((sz*2)) $((sz*2)) build/icon_1024.png --out "$ICONDIR/icon_${sz}x${sz}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONDIR" -o packaging/AppIcon.icns
fi
cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
if [ -d i18n ]; then
  mkdir -p "$APP/Contents/Resources/i18n"
  cp i18n/vocab-*.json "$APP/Contents/Resources/i18n/" 2>/dev/null || true
  cp i18n/onomaformer.json "$APP/Contents/Resources/i18n/" 2>/dev/null || true
  cp i18n/stylemap.json "$APP/Contents/Resources/i18n/" 2>/dev/null || true
fi

# データ提供のデフォルト設定を同梱（非git管理。insert-only RLS前提のanonキー）。
# これが無いと配布先の協力者は同意ONにしてもキューに貯まるだけで送信されない
if [ -f packaging/upload-default.json ]; then
  cp packaging/upload-default.json "$APP/Contents/Resources/upload-default.json"
  echo "==> upload-default.json を同梱（データ提供が配布先で有効）"
else
  echo "==> 警告: packaging/upload-default.json が無い——配布先はデータ提供できません"
fi

SIGN_ID="Developer ID Application: YOICHI OCHIAI (J2M6ZBXCB8)"
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "==> Developer ID 署名（hardened runtime）"
  codesign --force --options runtime --timestamp -s "$SIGN_ID" "$APP"

  # 公証（notarytool の keychain プロファイル "notary" がある場合のみ）
  if xcrun notarytool history --keychain-profile notary >/dev/null 2>&1; then
    echo "==> 公証を申請（数分かかります）"
    ditto -c -k --norsrc "$APP" build/notarize.zip
    xcrun notarytool submit build/notarize.zip --keychain-profile notary --wait
    echo "==> ステープル"
    xcrun stapler staple "$APP"
  else
    echo "==> 公証スキップ（プロファイル未設定: xcrun notarytool store-credentials notary）"
  fi
else
  echo "==> ad-hoc 署名（Developer ID 証明書が見つからないため）"
  codesign --force --deep -s - "$APP"
fi

echo "==> zip パッケージ作成"
STAGE=build/stage
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
cp "packaging/はじめにお読みください.txt" "$STAGE/"
ditto -c -k --norsrc "$STAGE" "dist/OnomatopeCursor-$VERSION.zip"

echo "==> 完成: dist/OnomatopeCursor-$VERSION.zip"
