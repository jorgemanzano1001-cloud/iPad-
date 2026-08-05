#!/usr/bin/env bash
# Línea de estado con aire de HUD: modelo, directorio y rama git.
# Claude Code pasa un JSON por stdin y pinta la primera línea de stdout.

set -uo pipefail

payload="$(cat)"

read -r model dir <<<"$(printf '%s' "$payload" | python3 -c '
import json, sys, os
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
model = (d.get("model") or {}).get("display_name") or "?"
ws = d.get("workspace") or {}
cwd = ws.get("current_dir") or d.get("cwd") or os.getcwd()
print(model.replace(" ", "_"), os.path.basename(cwd.rstrip("/")) or "/")
' 2>/dev/null)"

branch="$(git branch --show-current 2>/dev/null)"
[ -n "$branch" ] && branch=" · ${branch}"

# Marca los cambios sin commitear: es lo que más se olvida antes de cerrar.
dirty=""
if [ -n "$(git status --porcelain 2>/dev/null | head -1)" ]; then
  dirty="*"
fi

printf 'J.A.R.V.I.S. · %s · %s%s%s\n' "${model//_/ }" "$dir" "$branch" "$dirty"
