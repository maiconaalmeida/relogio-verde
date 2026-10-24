$ErrorActionPreference = 'Stop'
try {
    $target = Join-Path $env:LOCALAPPDATA 'RelogioVerde\RelogioVerde.scr'
    if (!(Test-Path $target)) { throw 'Relogio nao instalado. Execute Instalar.cmd primeiro.' }
    Write-Host 'Abrindo o relogio. Pressione uma tecla ou mova o mouse para sair.'
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $target
    $info.Arguments = '/s'
    $info.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($info)
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "O relogio encerrou com codigo $($p.ExitCode). Consulte erro-execucao.txt." }
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
