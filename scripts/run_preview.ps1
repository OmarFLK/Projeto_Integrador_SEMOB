param(
    [int]$Port = 8080,
    [ValidateSet('web-server', 'edge', 'chrome')][string]$Device = 'web-server',
    [switch]$DebugMode
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools.ps1')
$semobTools = Get-SemobTools
$semobRepo = Split-Path -Parent $PSScriptRoot
Push-Location $semobRepo
try {
    if (-not (Test-Path -LiteralPath '.dart_tool/package_config.json')) {
        & $semobTools.Dart $semobTools.FlutterSnapshot --suppress-analytics pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao resolver dependências Flutter.' }
    }
    Write-Host "SEMOB DEMO: http://127.0.0.1:$Port"
    Write-Host 'Usuario: demo@semob.local | Senha: SemobDemo2026!'
    Write-Host 'Somente dados sinteticos em memoria. Nao inicia backend ou banco.'
    Write-Host 'Use Ctrl+C para encerrar.'
    if ($DebugMode) {
        & $semobTools.Dart $semobTools.FlutterSnapshot --suppress-analytics run --no-pub -d $Device --target tool/preview.dart --web-hostname 127.0.0.1 --web-port $Port
    } else {
        Write-Host 'Compilando demonstracao otimizada (release)...'
        & $semobTools.Dart $semobTools.FlutterSnapshot --suppress-analytics build web --release --no-pub --target tool/preview.dart --output .dart_tool/preview-web
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar a demonstracao.' }
        & $semobTools.Dart tool/serve_preview.dart $Port
    }
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar a demonstracao.' }
} finally { Pop-Location }
