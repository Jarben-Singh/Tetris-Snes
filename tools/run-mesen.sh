#!/usr/bin/env bash
# ============================================================
# run-mesen.sh
# Equivalente de run-mesen.ps1 para macOS / Linux.
# Abre una ROM en Mesen. La ruta del emulador se toma de:
#   1. la variable de entorno MESEN_PATH
#   2. la primera línea del archivo tools/mesen.path
#   3. /Applications/Mesen.app (macOS)
#   4. "Mesen" o "mesen" en el PATH
#
# MESEN_PATH puede apuntar a un bundle .app o a un ejecutable.
# Ejemplo (añadir a ~/.zshrc, luego reiniciar VS Code):
#   export MESEN_PATH="/Applications/Mesen.app"
# ============================================================

set -u

ROM="${1:-}"
if [ -z "$ROM" ]; then
    echo "Uso: run-mesen.sh <ruta-a-la-rom>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESEN="${MESEN_PATH:-}"

if [ -z "$MESEN" ] && [ -f "$SCRIPT_DIR/mesen.path" ]; then
    MESEN="$(head -n 1 "$SCRIPT_DIR/mesen.path" | tr -d '\r' | sed -e 's/^[[:space:]"]*//' -e 's/[[:space:]"]*$//')"
fi

if [ -z "$MESEN" ] && [ -d "/Applications/Mesen.app" ]; then
    MESEN="/Applications/Mesen.app"
fi

if [ -z "$MESEN" ]; then
    MESEN="$(command -v Mesen || command -v mesen || true)"
fi

if [ -z "$MESEN" ] || [ ! -e "$MESEN" ]; then
    echo
    echo "No se encontró Mesen."
    if [ -n "${MESEN_PATH:-}" ]; then
        echo "MESEN_PATH apunta a una ruta que no existe: $MESEN_PATH"
    else
        echo "Define la variable de entorno MESEN_PATH con la ruta a Mesen:"
    fi
    echo
    echo '    export MESEN_PATH="/Applications/Mesen.app"'
    echo "o crea el archivo tools/mesen.path con la ruta en una sola línea."
    echo
    echo "Después cierra y vuelve a abrir VS Code para que tome el cambio."
    exit 1
fi

if [ ! -f "$ROM" ]; then
    echo "No existe la ROM: $ROM" >&2
    exit 1
fi

if [ -d "$MESEN" ] && [ "${MESEN%.app}" != "$MESEN" ]; then
    # Bundle de macOS
    open -a "$MESEN" "$ROM"
else
    nohup "$MESEN" "$ROM" >/dev/null 2>&1 &
fi
