param([Parameter(Mandatory = $true)][string]$ApiOrigin)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools.ps1')
$semobUri = $null
if (-not [Uri]::TryCreate($ApiOrigin, [UriKind]::Absolute, [ref]$semobUri) -or
    $semobUri.Scheme -ne 'https' -or $semobUri.UserInfo -or $semobUri.Query -or
    $semobUri.Fragment -or $semobUri.AbsolutePath -ne '/') {
    throw 'ApiOrigin deve ser só a origem HTTPS da API, por exemplo https://semob-api.onrender.com (sem /api/v1).'
}
$semobTools = Get-SemobTools
$semobRepo = Split-Path -Parent $PSScriptRoot
Push-Location $semobRepo
try {
    & $semobTools.Dart $semobTools.FlutterSnapshot build web --release --no-pub '--dart-define=API_BASE_URL=/api/v1/'
    if ($LASTEXITCODE -ne 0) { throw 'Falha no build web. Execute flutter pub get antes.' }
    $semobConfig = @{
        framework = $null
        buildCommand = $null
        installCommand = $null
        outputDirectory = '.'
        rewrites = @(@{ source = '/api/:path*'; destination = ($semobUri.GetLeftPart([UriPartial]::Authority) + '/api/:path*') })
        headers = @(@{ source = '/index.html'; headers = @(@{ key = 'Cache-Control'; value = 'no-cache' }) })
    }
    $semobJson = $semobConfig | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $semobRepo 'build/web/vercel.json'), $semobJson, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $semobRepo 'build/web/.vercelignore'), ".env`n.env.*`n.vercel`n", [Text.UTF8Encoding]::new($false))
    Write-Output 'Build e proxy preparados em build/web. Para publicar, siga TUTORIAL_DEPLOY.md.'
} finally { Pop-Location }
