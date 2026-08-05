#!/usr/bin/env bash
# Reproduce this project's Claude Code setup in a fresh machine or container.
#
# Idempotent: safe to run on every session start. Exits in milliseconds once
# everything is already in place, so it never slows down a warm environment.
#
# Run manually with:  bash .claude/bootstrap.sh

set -uo pipefail

MARKETPLACE="claude-code-plugins"
MARKETPLACE_SOURCE="anthropics/claude-code"
PLUGINS=(
  agent-sdk-dev
  code-review
  commit-commands
  feature-dev
  hookify
  plugin-dev
  pr-review-toolkit
  security-guidance
)

log() { printf '[claude-bootstrap] %s\n' "$*" >&2; }

command -v claude >/dev/null 2>&1 || { log "claude CLI not on PATH; skipping."; exit 0; }

installed="$(claude plugin list 2>/dev/null || true)"

# Fast path: every plugin already present, nothing to do.
missing=()
for p in "${PLUGINS[@]}"; do
  case "$installed" in
    *"$p@$MARKETPLACE"*) ;;
    *) missing+=("$p") ;;
  esac
done
[ ${#missing[@]} -eq 0 ] && exit 0

if ! claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE"; then
  log "adding marketplace $MARKETPLACE_SOURCE"
  claude plugin marketplace add "$MARKETPLACE_SOURCE" >/dev/null 2>&1 \
    || { log "could not add marketplace (offline?); skipping plugin install."; exit 0; }
fi

for p in "${missing[@]}"; do
  log "installing $p"
  claude plugin install "$p@$MARKETPLACE" >/dev/null 2>&1 || log "failed to install $p"
done

log "done."
exit 0
