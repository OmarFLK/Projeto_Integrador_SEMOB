param([string]$Device = 'edge')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools.ps1')
$semobTools = Get-SemobTools
$semobRepo = Split-Path -Parent $PSScriptRoot
$semobBackend = Join-Path $semobRepo 'backend'
Push-Location $semobBackend
try {
    & $semobTools.Dart --suppress-analytics pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Falha nas dependências do backend.' }
    $semobReady = $false
    try { $semobReady = (Invoke-RestMethod 'http://127.0.0.1:8081/ready' -TimeoutSec 2).status -eq 'ok' } catch { }
    if (-not $semobReady) {
        if (-not $env:DATABASE_URL) { throw 'Configure DATABASE_URL com PostgreSQL local ou Neon. Consulte TUTORIAL_DEPLOY.md.' }
        $semobMigrationOutput = & $semobTools.Dart --suppress-analytics run bin/migrate.dart
        if ($LASTEXITCODE -ne 0) { throw 'Falha na conexão/migração PostgreSQL. Confira DATABASE_URL e DIRECT_DATABASE_URL.' }
        # Dart can print native-build status before the final JSON object.
        $semobMigrationJson = [regex]::Match(($semobMigrationOutput -join [Environment]::NewLine), '\{"schemaVersion"[^\r\n]*\}\s*$').Value
        if (-not $semobMigrationJson) { throw 'O migrador não retornou o status esperado.' }
        $semobMigration = $semobMigrationJson | ConvertFrom-Json
        if ($semobMigration.empty -and -not $env:SEMOB_ADMIN_PASSWORD) {
            $semobPassword = Read-Host 'Defina a senha inicial do administrador (mínimo 12 caracteres)' -AsSecureString
            $env:SEMOB_ADMIN_PASSWORD = [Net.NetworkCredential]::new('', $semobPassword).Password
            if ($env:SEMOB_ADMIN_PASSWORD.Length -lt 12) { throw 'Senha inicial muito curta.' }
        }
        New-Item -Path 'data' -ItemType Directory -Force | Out-Null
        $semobApiProcess = Start-Process -FilePath $semobTools.Dart `
            -ArgumentList @('--suppress-analytics', 'run', 'bin/server.dart') `
            -WorkingDirectory $semobBackend -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $semobBackend 'data/backend.log') `
            -RedirectStandardError (Join-Path $semobBackend 'data/backend-error.log')
        for ($semobAttempt = 0; $semobAttempt -lt 120; $semobAttempt++) {
            if ($semobApiProcess.HasExited) { throw 'A API encerrou. Consulte backend/data/backend-error.log.' }
            Start-Sleep -Seconds 1
            try { $semobReady = (Invoke-RestMethod 'http://127.0.0.1:8081/ready' -TimeoutSec 2).status -eq 'ok' } catch { }
            if ($semobReady) { break }
        }
    }
    if (-not $semobReady) { throw 'API indisponível. Consulte os logs do backend.' }
} finally { Pop-Location }
Push-Location $semobRepo
try {
    & $semobTools.Dart $semobTools.FlutterSnapshot run -d $Device --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1/
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao executar o frontend.' }
} finally { Pop-Location }
