#!/usr/bin/env bash
# Local-machine installer for the Codespace helpers.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$LOCAL_BIN"

# Keep the commands linked to this checkout so pulling dev-env updates them.
ln -sfn "$REPO/open-codespace-cursor" "$LOCAL_BIN/open-codespace-cursor"
ln -sfn "$REPO/open-codespace-cursor-ide" \
  "$LOCAL_BIN/open-codespace-cursor-ide"
ln -sfn "$REPO/open-codespace-terminal" "$LOCAL_BIN/open-codespace-terminal"
ln -sfn "$REPO/sync-claude-token-to-codespace" \
  "$LOCAL_BIN/sync-claude-token-to-codespace"

# Remove the legacy link created by older versions without touching a regular
# file or an unrelated symlink the user may have created under the same name.
LEGACY_COMMAND="$LOCAL_BIN/open-codespace"
if [[ -L "$LEGACY_COMMAND" ]] \
  && [[ "$(readlink "$LEGACY_COMMAND")" == "$REPO/open-codespace" ]]; then
  rm "$LEGACY_COMMAND"
  echo "removed:   $LEGACY_COMMAND"
fi

# Remove the misspelled compatibility link from the previous installer while
# leaving any regular file or unrelated symlink owned by the user untouched.
TYPO_COMMAND="$LOCAL_BIN/open-codespace-cusror-ide"
if [[ -L "$TYPO_COMMAND" ]] \
  && [[ "$(readlink "$TYPO_COMMAND")" == "$REPO/open-codespace-cursor-ide" ]]; then
  rm "$TYPO_COMMAND"
  echo "removed:   $TYPO_COMMAND"
fi

echo "installed: $LOCAL_BIN/open-codespace-cursor"
echo "installed: $LOCAL_BIN/open-codespace-cursor-ide"
echo "installed: $LOCAL_BIN/open-codespace-terminal"
echo "installed: $LOCAL_BIN/sync-claude-token-to-codespace"
