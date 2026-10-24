@echo off
setlocal
if not exist "%LOCALAPPDATA%\RelogioVerde" mkdir "%LOCALAPPDATA%\RelogioVerde"
echo Instalando Relogio Verde 2.1. Aguarde...
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1" > "%LOCALAPPDATA%\RelogioVerde\instalacao.log" 2>&1
set "RV_RESULT=%ERRORLEVEL%"
type "%LOCALAPPDATA%\RelogioVerde\instalacao.log"
echo.
echo Log: %LOCALAPPDATA%\RelogioVerde\instalacao.log
if not "%RV_RESULT%"=="0" echo A instalacao FALHOU. Envie o log acima para diagnostico.
pause
exit /b %RV_RESULT%
