# Build Flutter Web in locale (equivalente Windows di netlify_build.sh).
# Uso dalla root del progetto:
#   powershell -ExecutionPolicy Bypass -File .\scripts\netlify_build.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

Write-Host "==> Netlify build BackOffice (Flutter web, locale)"
Write-Host "    Root: $root"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release

if (-not (Test-Path "build\web\index.html")) {
    throw "ERRORE: build\web\index.html mancante"
}

Write-Host "==> Build OK: $root\build\web"
Pop-Location
