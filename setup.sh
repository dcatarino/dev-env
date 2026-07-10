#!/usr/bin/env bash
# Local-machine installer for the open-codespace helper.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$LOCAL_BIN"

# Keep the command linked to this checkout so pulling dev-env updates it.
ln -sfn "$REPO/open-codespace" "$LOCAL_BIN/open-codespace"

echo "installed: $LOCAL_BIN/open-codespace"
