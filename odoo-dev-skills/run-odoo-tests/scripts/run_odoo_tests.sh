#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Run an Odoo module's unit tests against a reusable test database.

Creates the database on first use, then re-runs the module's tests on every
invocation. Always binds free HTTP/gevent ports, so a running dev server never
causes "Address already in use". Prints a parsed pass/fail summary and exits
non-zero when tests fail.

Usage:
  run_odoo_tests.sh --modules LIST [options]

Options:
  --modules LIST      Comma-separated technical module names (required)
  --project-dir PATH  Project containing .codespace-env/odoo.conf (default: cwd)
  --database NAME     Reusable test database (default: odoo-test-1)
  --test-tags TAGS    Passed to --test-tags, e.g. /my_module:TestClass.test_01
  --upgrade           Use -u instead of -i (forces a code/schema reload)
  --log PATH          Log file (default: /tmp/odoo-tests-<database>.log)
  -h, --help          Show this help

Environment overrides: ODOO_PYTHON, ODOO_BIN.

Exit codes: 0 tests passed, 1 tests failed or did not run, 2 usage error.
EOF
}

modules=""
project_dir="$PWD"
database="odoo-test-1"
test_tags=""
mode="-i"
log_file=""

while (($#)); do
  case "$1" in
    --modules)
      modules="${2:-}"
      shift 2
      ;;
    --project-dir)
      project_dir="${2:-}"
      shift 2
      ;;
    --database)
      database="${2:-}"
      shift 2
      ;;
    --test-tags)
      test_tags="${2:-}"
      shift 2
      ;;
    --upgrade)
      mode="-u"
      shift
      ;;
    --log)
      log_file="${2:-}"
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

if [[ -z "$modules" ]]; then
  echo "error: --modules is required" >&2
  exit 2
fi

project_dir="${project_dir%/}"
config="$project_dir/.codespace-env/odoo.conf"
python_bin="${ODOO_PYTHON:-/home/odoo/.pyenv/shims/python3}"
odoo_bin="${ODOO_BIN:-/workspaces/odoo/odoo-bin}"
log_file="${log_file:-/tmp/odoo-tests-${database}.log}"

[[ "$modules" =~ ^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$ ]] || {
  echo "error: --modules must be a comma-separated list of technical names" >&2
  exit 2
}
[[ "$database" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || {
  echo "error: invalid database name: $database" >&2
  exit 2
}
[[ -f "$config" ]] || { echo "error: missing Odoo config: $config" >&2; exit 2; }
[[ -x "$python_bin" ]] || { echo "error: missing Python executable: $python_bin" >&2; exit 2; }
[[ -f "$odoo_bin" ]] || { echo "error: missing odoo-bin: $odoo_bin" >&2; exit 2; }

for command in psql python3; do
  command -v "$command" >/dev/null || { echo "error: required command not found: $command" >&2; exit 2; }
done

# A dev server usually holds 8069/8072. odoo-bin binds its ports before loading
# any module, so a collision means zero tests run — always take free ones.
free_port() {
  python3 -c 'import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()'
}

http_port=$(free_port)
gevent_port=$(free_port)

run_odoo() {
  (
    cd "$project_dir"
    "$python_bin" "$odoo_bin" -c "$config" -d "$database" \
      --stop-after-init --workers=0 --max-cron-threads=0 \
      --http-port="$http_port" --gevent-port="$gevent_port" "$@"
  )
}

database_exists=$(psql -h 127.0.0.1 -U odoo -d postgres -Atc \
  "SELECT 1 FROM pg_database WHERE datname = '$database'")

if [[ "$database_exists" != "1" ]]; then
  echo "Creating database '$database' and installing: $modules"
  echo "  (first run installs the dependency chain — this takes minutes)"
  run_odoo -i "$modules" --log-level=warn >"$log_file" 2>&1 || {
    echo "error: database initialisation failed; see $log_file" >&2
    tail -30 "$log_file" >&2
    exit 1
  }
fi

echo "Running tests: modules=$modules database=$database${test_tags:+ tags=$test_tags}"
echo "Log: $log_file"

test_args=("$mode" "$modules" --test-enable --log-level=test)
[[ -z "$test_tags" ]] || test_args+=(--test-tags "$test_tags")

set +e
run_odoo "${test_args[@]}" >"$log_file" 2>&1
odoo_status=$?
set -e

summary=$(grep -E "tests when loading" "$log_file" | tail -1 || true)

if [[ -z "$summary" ]]; then
  echo "FAILED: no test summary in the log — the tests did not run." >&2
  echo "odoo-bin exit status: $odoo_status" >&2
  grep -E "CRITICAL|ERROR:|Traceback|Address already in use" "$log_file" | tail -20 >&2 || true
  exit 1
fi

echo "$summary"

if [[ "$summary" =~ ([0-9]+)\ failed,\ ([0-9]+)\ error\(s\)\ of\ ([0-9]+)\ tests ]]; then
  failed="${BASH_REMATCH[1]}"
  errored="${BASH_REMATCH[2]}"
  total="${BASH_REMATCH[3]}"
else
  echo "FAILED: could not parse the test summary." >&2
  exit 1
fi

if ((failed == 0 && errored == 0 && odoo_status == 0)); then
  echo "PASSED: $total tests, 0 failed, 0 errors."
  exit 0
fi

echo "FAILED: $failed failed, $errored errored of $total tests." >&2
grep -E "FAIL:|ERROR:|AssertionError|Traceback" "$log_file" | tail -40 >&2 || true
echo "Full log: $log_file" >&2
exit 1
