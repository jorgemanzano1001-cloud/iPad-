#!/usr/bin/env bash
# Carga la persona JARVIS al arrancar cada sesión.
#
# Los output styles quedaron deprecados; la vía soportada es inyectar
# additionalContext desde un hook SessionStart. La persona vive en
# .claude/jarvis/PERSONA.md para poder editarla como markdown normal, sin
# pelearse con el escapado de JSON.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERSONA="$DIR/jarvis/PERSONA.md"

# Sin persona no hay nada que inyectar: salir en silencio deja la sesión intacta.
[ -r "$PERSONA" ] || exit 0

# Sin python3 el heredoc de abajo abortaría con 127, y como es el último comando
# ese código sería el del hook. Mejor renunciar a la persona que romper el
# arranque de la sesión.
command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$PERSONA" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as fh:
    persona = fh.read()

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": persona,
    }
}))
PY
