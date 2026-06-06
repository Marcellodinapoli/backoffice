# Alias: build MSIX (Setup.exe non piu usato).
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_creditcalc_setup.ps1

$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "build_creditcalc_msix.ps1")
