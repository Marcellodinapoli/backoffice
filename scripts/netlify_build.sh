#!/usr/bin/env bash
# Build Flutter Web su Netlify (Linux).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

echo "==> Netlify build BackOffice (Flutter web)"
echo "    Root: $ROOT"
echo "    Channel: $FLUTTER_CHANNEL"

if [[ ! -d "$FLUTTER_DIR/bin" ]]; then
  echo "==> Install Flutter ($FLUTTER_CHANNEL)..."
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release

echo "==> Build OK: build/web"
