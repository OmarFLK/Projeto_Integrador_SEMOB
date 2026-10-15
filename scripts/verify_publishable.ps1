$ErrorActionPreference = 'Stop'
$semobRepo = Split-Path -Parent $PSScriptRoot
Push-Location $semobRepo
try {
    $semobFiles = @(git -c core.quotepath=false ls-files --cached)
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível ler o índice Git.' }
    $semobBlocked = @($semobFiles | Where-Object {
        $_ -match '(^|/)(data|exports|backups|secrets|\.aws|\.ssh|\.vercel)(/|$)' -or
        ($_ -match '(^|/)\.env($|\.)' -and $_ -notmatch '(^|/)\.env\.example$') -or
        $_ -match '\.(csv|zip|7z|rar|gz|dump|bak|db|pem|key|p12|pfx|jks|keystore)$' -or
        $_ -match '\.(sqlite|sembast)' -or
        $_ -match '(^|/)(key\.properties|credentials\.json|[^/]*service-account[^/]*\.json)$'
    })
    if ($semobBlocked.Count -gt 0) {
        $semobBlocked | ForEach-Object { Write-Output "Arquivo privado no índice: $_" }
        throw 'Publicação bloqueada: retire dados/segredos do índice sem apagar os arquivos locais.'
    }
    Write-Output "Índice Git aprovado: $($semobFiles.Count) arquivos, sem bancos, datasets ou arquivos de segredos conhecidos."
} finally { Pop-Location }
