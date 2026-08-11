#!/usr/bin/env bash

# Shared implementation for the Cursor and terminal Codespace launchers.

codespace_name_from_input() {
  local input=$1

  if [[ "$input" =~ ^https://([[:alnum:]-]+)\.github\.dev/?([?#].*)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$input" =~ ^https://github\.com/codespaces/([[:alnum:]-]+)/?([?#].*)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  # Treat other URL-shaped values as mistakes instead of passing them to gh as
  # Codespace names and returning a less useful lookup error.
  if [[ "$input" =~ ^[[:alpha:]][[:alnum:]+.-]*:// ]]; then
    return 1
  fi

  printf '%s\n' "$input"
}

set_odoo_port_visibility() {
  local codespace_name=$1
  local visibility=$2
  local odoo_port=8069

  printf 'Making Odoo port %s %s on %s...\n' \
    "$odoo_port" "$visibility" "$codespace_name"
  if ! gh codespace ports visibility \
    "${odoo_port}:${visibility}" -c "$codespace_name"; then
    printf 'Could not make Odoo port %s %s. Ensure it is forwarded and that GitHub policy permits this visibility.\n' \
      "$odoo_port" "$visibility" >&2
    return 1
  fi

  if [[ "$visibility" == "public" ]]; then
    printf 'Odoo URL: https://%s-%s.app.github.dev/\n' \
      "$codespace_name" "$odoo_port"
  fi
}

publish_odoo_port() {
  set_odoo_port_visibility "$1" public
}

make_odoo_port_private() {
  set_odoo_port_visibility "$1" private
}

start_odoo_port_publication() {
  local codespace_name=$1

  # Do not make editor/terminal startup wait on another GitHub API request.
  (
    trap '' HUP
    publish_odoo_port "$codespace_name"
  ) &
}

parse_open_codespace_arguments() {
  local make_odoo_port_public=false
  local codespace_argument=""

  while (( $# > 0 )); do
    case "$1" in
      --public)
        make_odoo_port_public=true
        ;;
      -h|--help)
        printf 'help\t\n'
        return 0
        ;;
      -*)
        return 2
        ;;
      *)
        [[ -z "$codespace_argument" ]] || return 2
        codespace_argument=$1
        ;;
    esac
    shift
  done

  printf '%s\t%s\n' "$make_odoo_port_public" "$codespace_argument"
}

open_codespace_main() {
  local launcher=$1
  shift

  set -euo pipefail

  local command_name="open-codespace-${launcher}"

  die() {
    printf '%s: %s\n' "$command_name" "$*" >&2
    exit 1
  }

  command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) is not installed"
  command -v ssh >/dev/null 2>&1 || die "OpenSSH client (ssh) is not installed"
  if [[ "$launcher" == "cursor" || "$launcher" == "cursor-ide" ]]; then
    command -v cursor >/dev/null 2>&1 \
      || die "Cursor's shell command is not installed"
  elif [[ "$launcher" != "terminal" ]]; then
    die "unknown launcher: $launcher"
  fi

  local parsed_arguments make_odoo_port_public codespace_argument
  parsed_arguments=$(parse_open_codespace_arguments "$@") \
    || die "usage: $command_name [--public] [codespace-name-or-url]"
  IFS=$'\t' read -r make_odoo_port_public codespace_argument <<<"$parsed_arguments"
  if [[ "$make_odoo_port_public" == "help" ]]; then
    printf 'Usage: %s [--public] [codespace-name-or-url]\n' "$command_name"
    if [[ "$launcher" == "cursor" || "$launcher" == "cursor-ide" ]]; then
      printf 'Select and open a GitHub Codespace in Cursor.\n'
    else
      printf 'Select and connect to a GitHub Codespace in this terminal.\n'
    fi
    printf 'Use --public to make Odoo port 8069 publicly accessible.\n'
    exit 0
  fi

  local selection selected codespace_input codespace_name
  local repository_full_name repository_name
  local item_name item_repository item_state item_last_used index choice
  local -a codespaces

  if [[ -n "$codespace_argument" ]]; then
    codespace_input=$(codespace_name_from_input "$codespace_argument") \
      || die "unsupported Codespace URL: $codespace_argument"
    selection=$(gh codespace view -c "$codespace_input" --json name,repository \
      --jq '[.name, .repository] | @tsv')
    IFS=$'\t' read -r codespace_name repository_full_name <<<"$selection"
  else
    # Do not use gh's interactive selector here: it requires its own stdout to
    # be a terminal, while this script needs to capture the selected value.
    mapfile -t codespaces < <(
      gh codespace list --json name,repository,state,lastUsedAt \
        --jq '.[] | [.name, .repository, .state, .lastUsedAt] | @tsv'
    )

    (( ${#codespaces[@]} > 0 )) || die "your GitHub account has no Codespaces"

    if (( ${#codespaces[@]} == 1 )); then
      selected=${codespaces[0]}
    else
      [[ -r /dev/tty && -w /dev/tty ]] || {
        printf '%s\n' "${codespaces[@]}" >&2
        die "no terminal is available; run: $command_name CODESPACE_NAME"
      }

      printf 'Choose a Codespace:\n\n' >/dev/tty
      for index in "${!codespaces[@]}"; do
        IFS=$'\t' read -r item_name item_repository item_state item_last_used \
          <<<"${codespaces[$index]}"
        printf '  %2d) %-22s %-11s %s\n' \
          "$((index + 1))" "$item_repository" "$item_state" "$item_name" \
          >/dev/tty
      done

      while :; do
        printf '\nSelection [1-%d, q to cancel]: ' "${#codespaces[@]}" >/dev/tty
        IFS= read -r choice </dev/tty || die "selection cancelled"
        [[ "$choice" == "q" || "$choice" == "Q" ]] \
          && die "selection cancelled"
        if [[ "$choice" =~ ^[0-9]+$ ]] \
          && (( choice >= 1 && choice <= ${#codespaces[@]} )); then
          selected=${codespaces[$((choice - 1))]}
          break
        fi
        printf 'Please enter a number from 1 to %d.\n' \
          "${#codespaces[@]}" >/dev/tty
      done
    fi

    IFS=$'\t' read -r codespace_name repository_full_name _ _ <<<"$selected"
  fi

  repository_name=${repository_full_name##*/}

  [[ -n "$codespace_name" ]] || die "no Codespace was selected"
  [[ -n "$repository_name" ]] || die "could not determine the repository folder"

  local ssh_dir=${HOME}/.ssh
  local codespaces_config=${ssh_dir}/codespaces
  local ssh_config=${ssh_dir}/config
  local temporary_config
  temporary_config=$(mktemp)
  trap 'rm -f "$temporary_config"' EXIT

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  # Regenerate one clean entry instead of appending duplicate Host blocks.
  gh codespace ssh -c "$codespace_name" --config >"$temporary_config"
  local ssh_host
  ssh_host=$(awk '$1 == "Host" { print $2; exit }' "$temporary_config")
  [[ -n "$ssh_host" ]] \
    || die "gh did not generate an SSH host for $codespace_name"

  install -m 600 "$temporary_config" "$codespaces_config"
  rm -f "$temporary_config"
  trap - EXIT
  touch "$ssh_config"
  chmod 600 "$ssh_config"

  if ! grep -Fqx 'Include ~/.ssh/codespaces' "$ssh_config"; then
    printf '\nMatch all\nInclude ~/.ssh/codespaces\n' >>"$ssh_config"
  fi

  # Use a non-empty sentinel because OpenSSH flattens remote command arguments
  # and does not preserve an empty positional argument.
  local remote_workspace=-
  if [[ "$launcher" == "cursor" || "$launcher" == "cursor-ide" ]]; then
    remote_workspace="/tmp/cursor-${codespace_name}.code-workspace"
  fi
  local remote_bootstrap=/tmp/open-codespace-bootstrap.sh
  local remote_bootstrap_log=/tmp/open-codespace-bootstrap.log

  # Upload the bootstrap and, for Cursor, build its ephemeral workspace in one
  # SSH round trip. Neither file is inside the selected project repository.
  ssh "$ssh_host" bash -s -- \
    "$remote_workspace" "$repository_name" "$remote_bootstrap" <<'REMOTE_PREP'
set -euo pipefail
remote_workspace=$1
repository_name=$2
remote_bootstrap=$3
umask 077

if [[ "$remote_workspace" != "-" ]]; then
  printf '{\n  "folders": [\n    { "path": "/workspaces/%s" },\n    { "path": "/workspaces", "name": "workspaces" }\n  ]\n}\n' \
    "$repository_name" >"$remote_workspace"
fi

cat >"$remote_bootstrap" <<'REMOTE_BOOTSTRAP'
#!/usr/bin/env bash

set -euo pipefail

lock_dir=${HOME}/.cache/open-codespace-bootstrap.lock
mkdir -p "${HOME}/.cache"

if ! mkdir "$lock_dir" 2>/dev/null; then
  if [[ -f "$lock_dir/pid" ]] && kill -0 "$(<"$lock_dir/pid")" 2>/dev/null; then
    printf 'Bootstrap is already running.\n'
    exit 0
  fi
  rm -f "$lock_dir/pid"
  rmdir "$lock_dir" 2>/dev/null || true
  mkdir "$lock_dir"
fi
printf '%s\n' "$$" >"$lock_dir/pid"
trap 'rm -f "$lock_dir/pid"; rmdir "$lock_dir" 2>/dev/null || true' EXIT

ensure_line() {
  local line=$1
  local file=$2
  touch "$file"
  grep -Fqx "$line" "$file" || printf '\n%s\n' "$line" >>"$file"
}

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
REMOTE_BOOTSTRAP
REMOTE_PREP

  start_bootstrap() {
    # Detach both the local starter and remote bootstrap so setup survives the
    # launcher exiting or the interactive terminal connection closing.
    (
      ssh "$ssh_host" \
        "nohup bash '$remote_bootstrap' >'$remote_bootstrap_log' 2>&1 </dev/null &"
    ) >/dev/null 2>&1 &
  }

  focus_cursor_ide_window() {
    local workspace_name=$1

    # Cursor's protocol handler normally focuses the window it opens, but some
    # Linux window managers keep the previously active Agents window focused.
    # xdotool is optional; when it is available, focus the workspace window
    # created from this Codespace's uniquely named temporary workspace.
    command -v xdotool >/dev/null 2>&1 || return 0

    local window_id
    for _ in {1..50}; do
      window_id=$(xdotool search --class cursor \
        --name "cursor-${workspace_name}" 2>/dev/null | tail -n 1)
      if [[ -n "$window_id" ]]; then
        xdotool windowactivate --sync "$window_id" >/dev/null 2>&1 || true
        return 0
      fi
      sleep 0.1
    done
  }

  if [[ "$launcher" == "cursor" || "$launcher" == "cursor-ide" ]]; then
    printf 'Opening /workspaces/%s and /workspaces on %s in Cursor...\n' \
      "$repository_name" "$codespace_name"

    if [[ "$launcher" == "cursor-ide" ]]; then
      # Cursor 3.x can route the regular --remote workspace invocation into
      # its Agents/Glass window when another Cursor process is already open.
      # Its remote protocol handler explicitly forces classic IDE routing.
      local cursor_remote_url
      cursor_remote_url="cursor://vscode-remote/ssh-remote+${ssh_host}${remote_workspace}?windowId=_blank"
      cursor --classic --open-url -- "$cursor_remote_url"

      # The URL handler asks the window manager to focus the new window, but
      # some Linux window managers leave the old Agents window active.
      focus_cursor_ide_window "$codespace_name" >/dev/null 2>&1 &
    else
      cursor --new-window \
        --remote "ssh-remote+${ssh_host}" \
        "$remote_workspace"
    fi

    # Cursor receives its open request and bootstrap starts before the
    # synchronous visibility update, so a slow GitHub API call cannot delay it.
    start_bootstrap
    if [[ "$make_odoo_port_public" == true ]]; then
      publish_odoo_port "$codespace_name"
    else
      make_odoo_port_private "$codespace_name"
    fi
    printf 'Background setup started; inside the Codespace, follow it with:\n'
    printf '  tail -f %s\n' "$remote_bootstrap_log"
  else
    printf 'Connecting to /workspaces on %s...\n' "$codespace_name"
    if [[ "$make_odoo_port_public" == true ]]; then
      start_odoo_port_publication "$codespace_name"
    else
      (
        trap '' HUP
        make_odoo_port_private "$codespace_name"
      ) &
    fi
    start_bootstrap
    printf 'Background setup started; follow it from the Codespace with:\n'
    printf '  tail -f %s\n' "$remote_bootstrap_log"
    exec ssh -t "$ssh_host" \
      'cd /workspaces && exec "${SHELL:-/bin/bash}" -i'
  fi
}
