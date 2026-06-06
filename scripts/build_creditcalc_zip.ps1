# Alias: build MSIX (ZIP non piu usato).
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_creditcalc_zip.ps1

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "build_creditcalc_msix.ps1")
