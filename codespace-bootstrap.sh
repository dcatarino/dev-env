#!/usr/bin/env bash

# Installs Claude Code, NVM/Node.js 22, Codex, and this dev-env repository's
# remote setup inside a GitHub Codespace. The open-codespace launchers upload
# and run it in the background; from a Codespace opened in the browser, run:
#   curl -fsSL https://raw.githubusercontent.com/dcatarino/dev-env/main/codespace-bootstrap.sh | bash

# Shell startup lines are written literally so they expand in each new shell.
# shellcheck disable=SC2016

set -euo pipefail

ensure_line() {
  local line=$1
  local file=$2
  touch "$file"
  grep -Fqx "$line" "$file" || printf '\n%s\n' "$line" >>"$file"
}

main() {
  lock_dir=${HOME}/.cache/open-codespace-bootstrap.lock
  mkdir -p "${HOME}/.cache"

  if ! mkdir "$lock_dir" 2>/dev/null; then
    if [[ -f "$lock_dir/pid" ]] && kill -0 "$(<"$lock_dir/pid")" 2>/dev/null; then
      printf 'Bootstrap is already running; a launcher-started run logs to /tmp/open-codespace-bootstrap.log.\n'
      exit 0
    fi
    rm -f "$lock_dir/pid"
    rmdir "$lock_dir" 2>/dev/null || true
    mkdir "$lock_dir"
  fi
  printf '%s\n' "$$" >"$lock_dir/pid"
  trap 'rm -f "$lock_dir/pid"; rmdir "$lock_dir" 2>/dev/null || true' EXIT

  printf '[1/5] Configuring the shell environment...\n'
  ensure_line 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
  ensure_line 'export IS_SANDBOX=1' "$HOME/.bashrc"
  ensure_line 'export NVM_DIR="$HOME/.nvm"' "$HOME/.bashrc"
  ensure_line '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' "$HOME/.bashrc"
  ensure_line "alias claude='IS_SANDBOX=1 command claude --dangerously-skip-permissions'" "$HOME/.bashrc"

  # Keep the same behavior if a Codespace uses zsh instead of the default bash.
  ensure_line 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"
  ensure_line 'export IS_SANDBOX=1' "$HOME/.zshrc"
  ensure_line 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  ensure_line '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' "$HOME/.zshrc"
  ensure_line "alias claude='IS_SANDBOX=1 command claude --dangerously-skip-permissions'" "$HOME/.zshrc"

  export PATH="$HOME/.local/bin:$PATH"
  export IS_SANDBOX=1
  export NVM_DIR="$HOME/.nvm"

  printf '[2/5] Installing Claude Code if needed...\n'
  if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi

  printf '[3/5] Installing NVM and Node.js 22 if needed...\n'
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh \
      | PROFILE="$HOME/.bashrc" bash
  fi
  # shellcheck source=/dev/null
  \. "$NVM_DIR/nvm.sh"

  if [[ "$(nvm version 22)" == "N/A" ]]; then
    nvm install 22
  else
    nvm use 22
  fi
  nvm alias default 22

  printf '[4/5] Installing Codex if needed...\n'
  if ! command -v codex >/dev/null 2>&1; then
    npm install -g @openai/codex
  fi

  printf '[5/5] Installing the shared development environment...\n'
  dev_env_dir=/dev-env
  if [[ ! -e "$dev_env_dir" && ! -w / ]]; then
    if command -v sudo >/dev/null 2>&1 \
      && sudo -n install -d -o "$(id -u)" -g "$(id -g)" "$dev_env_dir"; then
      :
    else
      dev_env_dir=$HOME/dev-env
    fi
  fi

  if [[ ! -e "$dev_env_dir" ]]; then
    git clone https://github.com/dcatarino/dev-env "$dev_env_dir"
  elif [[ ! -d "$dev_env_dir/.git" ]]; then
    printf '%s exists but is not a Git checkout; cannot install dev-env.\n' \
      "$dev_env_dir" >&2
    exit 1
  fi

  # Keep an existing Codespace checkout current so it receives new skills and
  # installer changes before refreshing the shared agent environment.
  git -C "$dev_env_dir" pull --ff-only
  bash "$dev_env_dir/remote-codespace-setup.sh"

  printf '\nBootstrap complete.\n'
  printf 'Node:   %s\n' "$(node --version)"
  printf 'npm:    %s\n' "$(npm --version)"
  printf 'Claude: %s\n' "$(command -v claude)"
  printf 'Codex:  %s\n' "$(command -v codex)"
  printf 'dev-env: %s\n' "$dev_env_dir"
  printf '\nOpen a new terminal, or run: exec "$SHELL"\n'
  printf 'to load claude, codex, and Node.js in an existing shell.\n'
}

# Bash reads a piped script only as far as it executes, so an installer that
# reads standard input could swallow the rest of `curl ... | bash`. Parsing
# main first and detaching its input keeps piped and launcher runs identical.
main "$@" </dev/null
