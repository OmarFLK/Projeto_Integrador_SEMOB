param([string]$Archive = 'data/semob_transport_reports.zip', [string]$Output = 'data/exports')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools.ps1')
$semobTools = Get-SemobTools
Push-Location (Join-Path (Split-Path -Parent $PSScriptRoot) 'backend')
try {
    & $semobTools.Dart --suppress-analytics pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Falha nas dependências do backend.' }
    & $semobTools.Dart --suppress-analytics run bin/import_data.dart $Archive $Output
    if ($LASTEXITCODE -ne 0) { throw 'Falha na validação/importação dos dados.' }
} finally { Pop-Location }
