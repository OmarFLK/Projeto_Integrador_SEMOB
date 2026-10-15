$ErrorActionPreference = 'Stop'
function Get-SemobTools {
    $semobFlutterRoot = $env:FLUTTER_ROOT
    if (-not $semobFlutterRoot) {
        $semobFlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if ($semobFlutterCommand) {
            $semobFlutterRoot = Split-Path -Parent (Split-Path -Parent $semobFlutterCommand.Source)
        } else {
            $semobFlutterRoot = Join-Path $env:USERPROFILE 'development\flutter'
        }
    }
    $semobDart = Join-Path $semobFlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
    $semobSnapshot = Join-Path $semobFlutterRoot 'bin\cache\flutter_tools.snapshot'
    if (-not (Test-Path -LiteralPath $semobDart) -or -not (Test-Path -LiteralPath $semobSnapshot)) {
        throw 'Instale e inicialize o Flutter, ou configure FLUTTER_ROOT com a pasta do SDK.'
    }
    return @{ Dart = $semobDart; FlutterSnapshot = $semobSnapshot }
}
