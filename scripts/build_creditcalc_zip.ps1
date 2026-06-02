# Genera il ZIP Windows di CreditCalc (wrapper verso creditcalc-tool).
# Uso dalla root backoffice:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_creditcalc_zip.ps1
#
# Opzionale:
#   $env:CREDITCALC_ROOT = "C:\percorso\creditcalc-tool"

$ErrorActionPreference = "Stop"
$backofficeRoot = Split-Path -Parent $PSScriptRoot
$defaultCreditcalc = Join-Path (Split-Path $backofficeRoot -Parent) "creditcalc-tool"
$creditcalcRoot = if ($env:CREDITCALC_ROOT) { $env:CREDITCALC_ROOT } else { $defaultCreditcalc }

$buildScript = Join-Path $creditcalcRoot "scripts\build_windows_release.ps1"
if (-not (Test-Path $buildScript)) {
    throw "Repo CreditCalc non trovato: $creditcalcRoot`nImposta CREDITCALC_ROOT o clona creditcalc-tool accanto a backoffice."
}

Write-Host "CreditCalc root: $creditcalcRoot"
& $buildScript

$pubspec = Join-Path $creditcalcRoot "credit_calc\pubspec.yaml"
$line = Get-Content $pubspec | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
$version = "1.0.0"
if ($line -match 'version:\s*(\d+\.\d+\.\d+)') { $version = $Matches[1] }

$setup = Join-Path $creditcalcRoot "dist\CreditCalc-$version-Setup.exe"
$zip = Join-Path $creditcalcRoot "dist\CreditCalc-$version-win64.zip"
Write-Host ""
Write-Host "Prossimo passo nel BackOffice (menu App Windows):"
Write-Host "  1. Versione release: $version"
if (Test-Path $setup) {
  Write-Host "  2. Carica INSTALLER: $setup"
} else {
  Write-Host "  2. Installer mancante - installa Inno Setup 6 e riesegui lo script"
  Write-Host "     Fallback ZIP: $zip"
}
Write-Host "  3. Salva configurazione"
