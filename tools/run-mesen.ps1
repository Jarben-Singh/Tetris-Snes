# ============================================================
# run-mesen.ps1
# Abre una ROM en Mesen. La ruta del emulador se toma de la
# variable de entorno MESEN_PATH; si no está definida, se busca
# Mesen.exe en el PATH.
#
# Configuración (una sola vez por equipo, luego reiniciar VS Code):
#   setx MESEN_PATH "C:\ruta\a\Mesen.exe"
# ============================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Rom
)

$mesen = $env:MESEN_PATH

if (-not $mesen) {
    $cmd = Get-Command Mesen.exe -ErrorAction SilentlyContinue
    if ($cmd) { $mesen = $cmd.Source }
}

if (-not $mesen -or -not (Test-Path -LiteralPath $mesen)) {
    Write-Host ""
    Write-Host "No se encontró Mesen." -ForegroundColor Red
    if ($env:MESEN_PATH) {
        Write-Host "MESEN_PATH apunta a una ruta que no existe: $env:MESEN_PATH"
    } else {
        Write-Host "Define la variable de entorno MESEN_PATH con la ruta a Mesen.exe:"
    }
    Write-Host ""
    Write-Host '    setx MESEN_PATH "C:\ruta\a\Mesen.exe"'
    Write-Host ""
    Write-Host "Después cierra y vuelve a abrir VS Code para que tome el cambio."
    exit 1
}

if (-not (Test-Path -LiteralPath $Rom)) {
    Write-Host "No existe la ROM: $Rom" -ForegroundColor Red
    exit 1
}

Start-Process -FilePath $mesen -ArgumentList "`"$Rom`""
