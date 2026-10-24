$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'RelogioVerde'
$desktop = 'HKCU:\Control Panel\Desktop'
$stage = $null
try {
    Write-Host 'RELOGIO VERDE 2.1 - INSTALACAO E DIAGNOSTICO'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($name in @('RelogioVerde.cs','Desinstalar.ps1','Desinstalar.cmd','Testar.ps1','Testar.cmd','Configuracoes.cmd')) {
        if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $name))) {
            throw "Arquivo ausente: $name. Extraia TODO o ZIP antes de instalar."
        }
    }
    foreach ($policyPath in @('HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop','HKLM:\Software\Policies\Microsoft\Windows\Control Panel\Desktop')) {
        if (Test-Path $policyPath) {
            $policy = Get-ItemProperty $policyPath
            if ($policy.PSObject.Properties['SCRNSAVE.EXE'] -or $policy.ScreenSaveActive -eq '0') {
                throw 'Uma politica do Windows controla o protetor de tela. A instalacao nao alterou essa politica.'
            }
        }
    }
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (!(Test-Path $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
    if (!(Test-Path $compiler)) { throw 'Compilador do .NET Framework nao encontrado neste Windows. Envie o log de instalacao.' }
    $stage = Join-Path $dest ('build-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    $source = Join-Path $PSScriptRoot 'RelogioVerde.cs'
    $built = Join-Path $stage 'RelogioVerde.exe'
    Write-Host '1/4 Compilando o programa...'
    & $compiler /nologo /target:winexe /optimize+ /platform:anycpu "/out:$built" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll $source
    if ($LASTEXITCODE -ne 0 -or !(Test-Path $built)) { throw 'Compilacao falhou. O erro do compilador esta neste log.' }
    Write-Host '2/4 Testando a inicializacao e o desenho nativo...'
    $render = Join-Path $stage 'teste.png'
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $built
    $info.Arguments = '/render "' + $render + '"'
    $info.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($info)
    if (!$process.WaitForExit(20000)) { $process.Kill(); throw 'O teste de desenho nao terminou em 20 segundos.' }
    if ($process.ExitCode -ne 0 -or !(Test-Path $render)) { throw 'O executavel nao conseguiu desenhar. Consulte tambem erro-execucao.txt na pasta instalada.' }
    if ((Get-Item $render).Length -lt 100) { throw 'Imagem de teste invalida.' }
    $target = Join-Path $dest 'RelogioVerde.scr'
    Write-Host '3/4 Instalando os arquivos...'
    Copy-Item -LiteralPath $built -Destination $target -Force
    Copy-Item -LiteralPath $render -Destination (Join-Path $dest 'Teste-nativo.png') -Force
    foreach ($name in @('Desinstalar.ps1','Desinstalar.cmd','Testar.ps1','Testar.cmd','Configuracoes.cmd')) {
        $src = Join-Path $PSScriptRoot $name
        if ($src -ine (Join-Path $dest $name)) { Copy-Item -LiteralPath $src -Destination $dest -Force }
    }
    Write-Host '4/4 Selecionando e ativando o protetor para este usuario...'
    $backup = Join-Path $dest 'config-anterior.json'
    if (!(Test-Path $backup)) {
        $state = @{}
        $key = Get-Item $desktop
        foreach ($name in @('SCRNSAVE.EXE','ScreenSaveActive','ScreenSaveTimeOut')) {
            $state[$name] = $key.GetValue($name, $null)
        }
        $state | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
    }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ScreenSaverSettings {
    [DllImport("user32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SystemParametersInfo(uint action, uint value, IntPtr pointer, uint flags);
}
'@
    New-ItemProperty $desktop -Name 'SCRNSAVE.EXE' -Value $target -PropertyType String -Force | Out-Null
    # SPI_SETSCREENSAVEACTIVE and SPI_SETSCREENSAVETIMEOUT, broadcast + persist.
    if (![ScreenSaverSettings]::SystemParametersInfo(17, 1, [IntPtr]::Zero, 3)) { throw 'Windows recusou ativar o protetor.' }
    $timeout = 0
    $existing = (Get-ItemProperty $desktop).ScreenSaveTimeOut
    if (![int]::TryParse([string]$existing, [ref]$timeout) -or $timeout -lt 1) { $timeout = 300 }
    if (![ScreenSaverSettings]::SystemParametersInfo(15, [uint32]$timeout, [IntPtr]::Zero, 3)) { throw 'Windows recusou o tempo de espera.' }
    $selected = (Get-ItemProperty $desktop).'SCRNSAVE.EXE'
    if ($selected -ine $target -or !(Test-Path -LiteralPath $selected)) { throw 'A selecao do protetor nao foi confirmada.' }
    Write-Host "INSTALADO: $selected"
    Write-Host "Tempo de espera: $timeout segundos. A opcao de senha foi preservada."
    Write-Host 'Abra Testar.cmd para ver o relogio imediatamente. Mova o mouse para sair.'
    Write-Host 'A janela de configuracoes do Windows sera aberta agora.'
    Start-Process -FilePath "$env:WINDIR\System32\control.exe" -ArgumentList 'desk.cpl,,@screensaver'
    exit 0
} catch {
    Write-Host ('FALHA: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    Write-Host 'Envie o arquivo instalacao.log mostrado pelo instalador.'
    exit 1
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
