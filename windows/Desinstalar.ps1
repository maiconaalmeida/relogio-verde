$ErrorActionPreference = 'Stop'
try {
    $dest = Join-Path $env:LOCALAPPDATA 'RelogioVerde'
    $target = Join-Path $dest 'RelogioVerde.scr'
    $desktop = 'HKCU:\Control Panel\Desktop'
    $current = (Get-ItemProperty $desktop -Name 'SCRNSAVE.EXE' -ErrorAction SilentlyContinue).'SCRNSAVE.EXE'
    if ($current -and $current.Trim('"') -ieq $target) {
        $backup = Join-Path $dest 'config-anterior.json'
        $state = $null
        if (Test-Path $backup) { $state = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json }
        $oldSaver = if ($state) { $state.'SCRNSAVE.EXE' } else { $null }
        # A version 2.0 selection may point to this same application.
        if ($oldSaver -and $oldSaver.Trim('"') -ine $target -and (Test-Path -LiteralPath $oldSaver.Trim('"'))) {
            New-ItemProperty $desktop -Name 'SCRNSAVE.EXE' -Value $oldSaver -PropertyType String -Force | Out-Null
        } else {
            Remove-ItemProperty $desktop -Name 'SCRNSAVE.EXE' -ErrorAction SilentlyContinue
            $oldSaver = $null
        }
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RestoreSaver {
    [DllImport("user32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SystemParametersInfo(uint action, uint value, IntPtr pointer, uint flags);
}
'@
        $active = if ($oldSaver -and $state.ScreenSaveActive -eq '1') { 1 } else { 0 }
        if (![RestoreSaver]::SystemParametersInfo(17, [uint32]$active, [IntPtr]::Zero, 3)) { throw 'Windows recusou desativar/restaurar o protetor.' }
        $timeout = 0
        if ($state -and [int]::TryParse([string]$state.ScreenSaveTimeOut, [ref]$timeout) -and $timeout -gt 0) {
            if (![RestoreSaver]::SystemParametersInfo(15, [uint32]$timeout, [IntPtr]::Zero, 3)) { throw 'Windows recusou restaurar o tempo de espera.' }
        }
    }
    foreach ($name in @('RelogioVerde.scr','Teste-nativo.png','Testar.ps1','Testar.cmd','Configuracoes.cmd','config-anterior.json','Desinstalar.cmd','Desinstalar.ps1')) {
        $file = Join-Path $dest $name
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    }
    Write-Host 'Relogio removido. Logs de diagnostico foram preservados na pasta instalada.'
    Start-Process -FilePath "$env:WINDIR\System32\control.exe" -ArgumentList 'desk.cpl,,@screensaver'
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
