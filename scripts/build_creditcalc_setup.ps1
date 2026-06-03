# Build CreditCalc Windows e genera SOLO CreditCalc-<versione>-Setup.exe
# Uso dalla root backoffice:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_creditcalc_setup.ps1

$ErrorActionPreference = "Stop"
$backofficeRoot = Split-Path -Parent $PSScriptRoot
$defaultCreditcalc = Join-Path (Split-Path $backofficeRoot -Parent) "creditcalc-tool"
$creditcalcRoot = if ($env:CREDITCALC_ROOT) { $env:CREDITCALC_ROOT } else { $defaultCreditcalc }

$buildScript = Join-Path $creditcalcRoot "scripts\build_windows_release.ps1"
if (-not (Test-Path $buildScript)) {
    throw "Repo CreditCalc non trovato: $creditcalcRoot"
}

Write-Host "CreditCalc root: $creditcalcRoot"
& $buildScript

$pubspec = Join-Path $creditcalcRoot "credit_calc\pubspec.yaml"
$line = Get-Content $pubspec | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
$version = "1.0.0"
if ($line -match 'version:\s*(\d+\.\d+\.\d+)') { $version = $Matches[1] }

$setup = Join-Path $creditcalcRoot "dist\CreditCalc-$version-Setup.exe"
Write-Host ""
Write-Host "========================================"
Write-Host "  UNICO FILE DA CARICARE SU FIREBASE:"
Write-Host "  $setup"
Write-Host "========================================"
Write-Host ""
Write-Host "BackOffice -> App Windows -> Carica Setup.exe -> Usa"
