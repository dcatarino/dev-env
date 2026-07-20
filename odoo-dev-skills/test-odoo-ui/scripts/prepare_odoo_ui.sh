#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Prepare an Odoo Codespace database for browser-based E2E testing.

Usage:
  prepare_odoo_ui.sh --project-dir PATH [options]

Options:
  --project-dir PATH  Project containing .codespace-env/odoo.conf (required)
  --database NAME     Reusable test database (default: odoo_ui_e2e)
  --modules LIST      Comma-separated modules to install or upgrade
  --base-url URL      Local URL used for readiness checks (default: http://127.0.0.1:8069)
  --timeout SECONDS   Odoo startup timeout (default: 180)
  -h, --help          Show this help
EOF
}

project_dir=""
database="odoo_ui_e2e"
modules=""
base_url="http://127.0.0.1:8069"
timeout=180

while (($#)); do
  case "$1" in
    --project-dir)
      project_dir="${2:-}"
      shift 2
      ;;
    --database)
      database="${2:-}"
      shift 2
      ;;
    --modules)
      modules="${2:-}"
      shift 2
      ;;
    --base-url)
      base_url="${2:-}"
      shift 2
      ;;
    --timeout)
      timeout="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$project_dir" ]]; then
  echo "error: --project-dir is required" >&2
  exit 2
fi

project_dir="${project_dir%/}"
config="$project_dir/.codespace-env/odoo.conf"
start_script="$project_dir/.devcontainer/scripts/task_start_odoo.sh"
python_bin="${ODOO_PYTHON:-/home/odoo/.pyenv/shims/python3}"
odoo_bin="${ODOO_BIN:-/workspaces/odoo/odoo-bin}"

[[ -f "$config" ]] || { echo "error: missing Odoo config: $config" >&2; exit 2; }
[[ -f "$start_script" ]] || { echo "error: missing Odoo start script: $start_script" >&2; exit 2; }
[[ -x "$python_bin" ]] || { echo "error: missing Python executable: $python_bin" >&2; exit 2; }
[[ -f "$odoo_bin" ]] || { echo "error: missing odoo-bin: $odoo_bin" >&2; exit 2; }
[[ "$database" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || {
  echo "error: invalid database name: $database" >&2
  exit 2
}
if [[ -n "$modules" && ! "$modules" =~ ^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$ ]]; then
  echo "error: --modules must be a comma-separated list of technical names" >&2
  exit 2
fi
[[ "$timeout" =~ ^[1-9][0-9]*$ ]] || { echo "error: --timeout must be a positive integer" >&2; exit 2; }

for command in curl psql sudo; do
  command -v "$command" >/dev/null || { echo "error: required command not found: $command" >&2; exit 2; }
done

run_odoo_setup() {
  sudo -u odoo -i "$python_bin" "$odoo_bin" \
    -c "$config" -d "$database" --stop-after-init --no-http \
    --workers=0 --max-cron-threads=0 --log-level=warn "$@"
}

database_exists=$(psql -h 127.0.0.1 -U odoo -d postgres -Atc \
  "SELECT 1 FROM pg_database WHERE datname = '$database'")

if [[ "$database_exists" != "1" ]]; then
  install_modules="base,web"
  [[ -z "$modules" ]] || install_modules+=",$modules"
  echo "Creating database '$database' with: $install_modules"
  run_odoo_setup -i "$install_modules" --without-demo=all
elif [[ -n "$modules" ]]; then
  echo "Upgrading modules in '$database': $modules"
  run_odoo_setup -u "$modules"
else
  echo "Reusing database '$database'"
fi

echo "Setting the test login to admin/admin"
printf '%s\n' \
  "admin = env.ref('base.user_admin').sudo()" \
  "admin.write({'login': 'admin', 'password': 'admin'})" \
  | sudo -u odoo -i "$python_bin" "$odoo_bin" shell \
      -c "$config" -d "$database" --no-http --log-level=warn

login_url="${base_url%/}/web/login?db=$database"
if ! curl --silent --fail --output /dev/null "$login_url"; then
  server_log="/tmp/test-odoo-ui-${database}.log"
  echo "Starting Odoo; server log: $server_log"
  (
    cd "$project_dir"
    nohup bash "$start_script" >"$server_log" 2>&1 </dev/null &
  )

  elapsed=0
  until curl --silent --fail --output /dev/null "$login_url"; do
    if ((elapsed >= timeout)); then
      echo "error: Odoo did not become ready within ${timeout}s; see $server_log" >&2
      exit 1
    fi
    sleep 2
    ((elapsed += 2))
  done
fi

tmp_dir=$(mktemp -d)
trap 'rm -r -- "$tmp_dir"' EXIT
cookie_jar="$tmp_dir/cookies"
login_page="$tmp_dir/login.html"
web_page="$tmp_dir/web.html"
session_json="$tmp_dir/session.json"

curl --silent --show-error --fail --location --max-redirs 3 \
  -c "$cookie_jar" -b "$cookie_jar" -o "$login_page" "$login_url"
csrf_token=$(sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$login_page")
[[ -n "$csrf_token" ]] || { echo "error: login page did not contain a CSRF token" >&2; exit 1; }

curl --silent --show-error --fail --location \
  -c "$cookie_jar" -b "$cookie_jar" -o "$web_page" \
  --data-urlencode "csrf_token=$csrf_token" \
  --data-urlencode "db=$database" \
  --data-urlencode 'login=admin' \
  --data-urlencode 'password=admin' \
  --data-urlencode 'redirect=/web' \
  "$login_url"

curl --silent --show-error --fail -b "$cookie_jar" -o "$session_json" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"call","params":{},"id":1}' \
  "${base_url%/}/web/session/get_session_info"

python3 - "$session_json" "$database" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as session_file:
    payload = json.load(session_file)

session = payload.get("result") or {}
expected_database = sys.argv[2]
if session.get("uid") != 2 or session.get("db") != expected_database or session.get("username") != "admin":
    raise SystemExit(f"error: admin web login verification failed: {session!r}")
PY

browser_base_url="${base_url%/}"
if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
  browser_base_url="https://${CODESPACE_NAME}-8069.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
fi

echo "Ready: database=$database user=admin uid=2"
echo "ODOO_UI_URL=${browser_base_url}/web/login?db=${database}"
