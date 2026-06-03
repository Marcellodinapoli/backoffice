#!/usr/bin/env bash
# Build Flutter Web su Netlify (Linux).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Cache tra deploy (Netlify conserva .cache se configurato in UI)
# Netlify persiste /opt/buildhome tra i deploy
CACHE_ROOT="${NETLIFY_BUILD_CACHE:-${NETLIFY_BUILD_BASE:-$HOME}/.netlify_cache}"
FLUTTER_DIR="${CACHE_ROOT}/flutter"
export PUB_CACHE="${CACHE_ROOT}/pub-cache"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

echo "==> Netlify build BackOffice (Flutter web)"
echo "    Root: $ROOT"
echo "    Flutter: $FLUTTER_DIR"
echo "    Channel: $FLUTTER_CHANNEL"

if [[ ! -f "$FLUTTER_DIR/bin/flutter" ]]; then
  echo "==> Install Flutter ($FLUTTER_CHANNEL)..."
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release

if [[ ! -f "$ROOT/build/web/index.html" ]]; then
  echo "ERRORE: build/web/index.html mancante"
  exit 1
fi

echo "==> Build OK: $ROOT/build/web"
