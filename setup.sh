#!/usr/bin/env bash
# Local-machine installer for the Codespace helpers.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$LOCAL_BIN"

# Keep the commands linked to this checkout so pulling dev-env updates them.
ln -sfn "$REPO/open-codespace-cursor" "$LOCAL_BIN/open-codespace-cursor"
ln -sfn "$REPO/open-codespace-terminal" "$LOCAL_BIN/open-codespace-terminal"

# Remove the legacy link created by older versions without touching a regular
# file or an unrelated symlink the user may have created under the same name.
LEGACY_COMMAND="$LOCAL_BIN/open-codespace"
if [[ -L "$LEGACY_COMMAND" ]] \
  && [[ "$(readlink "$LEGACY_COMMAND")" == "$REPO/open-codespace" ]]; then
  rm "$LEGACY_COMMAND"
  echo "removed:   $LEGACY_COMMAND"
fi

echo "installed: $LOCAL_BIN/open-codespace-cursor"
echo "installed: $LOCAL_BIN/open-codespace-terminal"
