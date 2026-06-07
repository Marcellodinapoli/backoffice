# Alias: stesso script di build_creditcalc_setup.ps1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "build_creditcalc_setup.ps1")
