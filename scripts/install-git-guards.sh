#!/usr/bin/env bash
# Run ONCE per clone, from the root of ANY repo that calls this floor's workflows.
# One-liner:
#
#   curl -sSL https://raw.githubusercontent.com/katalor-group/katalor-ci-floor/v1/scripts/install-git-guards.sh | bash
#
# Installs the pre-push secret-scan guard (.githooks/pre-push in THIS repo) into
# the calling repo's own git hooks -- the free stand-in for GitHub push protection.
# Pinned to the @v1 tag, never @main, so a hook installed today doesn't silently
# change behavior on a later run without a deliberate re-install (same pin
# discipline as the reusable workflows this floor repo hosts).
set -euo pipefail

REF="v1"
RAW="https://raw.githubusercontent.com/katalor-group/katalor-ci-floor/${REF}/.githooks/pre-push"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "install-git-guards.sh: not inside a git repo." >&2
  exit 1
}

mkdir -p "$ROOT/.githooks"
curl -sSL "$RAW" -o "$ROOT/.githooks/pre-push"
chmod +x "$ROOT/.githooks/pre-push"
git -C "$ROOT" config core.hooksPath "$ROOT/.githooks"

echo "git guards installed for $(basename "$ROOT"):"
echo "  - pre-push secret scan (katalor-ci-floor@${REF}) -- verified secrets block the push"
echo "  - re-run this script to pick up a newer @${REF}; it always re-fetches"
