#!/bin/bash
# Сборка TypeSpeed.app. Запуск: bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Не найден компилятор Swift. Установи Command Line Tools:"
  echo "    xcode-select --install"
  echo "и запусти bash build.sh еще раз."
  exit 1
fi

APP="build/TypeSpeed.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Компиляция..."
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos11.0" Sources/main.swift \
  -o "$APP/Contents/MacOS/TypeSpeed" \
  -framework Cocoa -framework WebKit

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/* "$APP/Contents/Resources/"

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Готово: $(pwd)/$APP"
if [ "${1:-}" = "install" ]; then
  rm -rf "/Applications/TypeSpeed.app"
  cp -R "$APP" /Applications/
  echo "Установлено в /Applications"
  open "/Applications/TypeSpeed.app"
else
  open "$APP"
fi
