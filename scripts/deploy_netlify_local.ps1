# Build web in locale e pubblica su Netlify (se il build remoto fallisce).
# Prerequisito: npm install -g netlify-cli   oppure   npx netlify-cli
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy_netlify_local.ps1
#
# Prima volta: netlify login

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

Write-Host "==> flutter build web --release"
flutter pub get
flutter build web --release

if (-not (Test-Path "build\web\index.html")) {
    throw "Build fallita: manca build\web\index.html"
}

Write-Host "==> netlify deploy --prod"
netlify deploy --prod --dir=build\web

Pop-Location
