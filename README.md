# SNES Tetris

Implementación de Tetris para Super Nintendo (SNES) escrita en ensamblador 65816 puro, sin frameworks de alto nivel como PVSnesLib.

## Descripción

Proyecto educativo/hobby que reconstruye la lógica clásica de Tetris (tablero, piezas, rotación, línea completa, puntuación) directamente sobre el hardware de la SNES, manejando a bajo nivel la PPU, DMA, entrada de controles y audio.

## Toolchain

- **Ensamblador/Linker:** [WLA-DX](https://github.com/vhelin/wla-dx) (`wla-65816` + `wlalink`)
- **CPU objetivo:** Ricoh 5A22 (65816)
- Sin PVSnesLib ni otras librerías de alto nivel; todo el código es ensamblador puro.

## Estructura del proyecto

```
src/        Código fuente en ensamblador (core, game, engine, data)
include/    Cabeceras compartidas (hardware, macros, mapa de RAM)
gfx/        Assets gráficos (tiles, sprites, paletas)
audio/      Assets de audio (SPC, BRR)
build/      Salida de compilación (generado, ignorado por git)
tools/      Scripts y utilidades de desarrollo
docs/       Documentación de diseño y roadmap
tests/      Pruebas
```

## Cómo compilar

> Pendiente: se documentará el proceso de compilación con WLA-DX una vez esté listo el Makefile.

```
# Placeholder
make
```

### Configuración por plataforma (tareas de VS Code)

**Windows:** usa los binarios incluidos en `tools/` y `tools/run-mesen.ps1`. Define `MESEN_PATH` (`setx MESEN_PATH "C:\ruta\a\Mesen.exe"`) o crea `tools/mesen.path`.

**macOS / Linux:**

1. Instala WLA-DX: `brew install wla-dx` (deben quedar `wla-65816` y `wlalink` en el PATH).
2. Instala Mesen (por defecto se busca en `/Applications/Mesen.app`) o define la ruta:
   `export MESEN_PATH="/Applications/Mesen.app"` en `~/.zshrc`, o escríbela en `tools/mesen.path`.
3. Reinicia VS Code y ejecuta las tareas igual que en Windows (`Ctrl/Cmd+Shift+B` para compilar).

## Licencia

Ver [LICENSE](LICENSE).
