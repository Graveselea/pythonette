#!/usr/bin/env bash
set -u
# No "set -e": we want to run ALL checks and summarize at the end.

# ============================================================
# tests_PYTHON/check.sh
# STRICT 42 MODE + AUTO SUMMARY + LOGS + COLORS/EMOJI
#
# Runs (project root):
#   - flake8      (style/errors)
#   - mypy        (type hints)
#   - pydocstyle  (docstrings)
#
# Behaviour:
#   - runs ALL checks (no early stop)
#   - generates logs in tests_PYTHON/logs/
#   - prints per-tool status + issue count + paths to logs
#   - STRICT: any failure => exit 1 (KO)
#   - colors/emojis enabled only when stdout is a terminal (TTY)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

LOG_DIR="$SCRIPT_DIR/logs"

# Clean old logs at each run
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

# Timestamp safe for filenames
TS="$(date +%Y%m%d_%H%M%S)"

FLAKE8_LOG="$LOG_DIR/flake8_$TS.log"
MYPY_LOG="$LOG_DIR/mypy_$TS.log"
PYDOC_LOG="$LOG_DIR/pydocstyle_$TS.log"

# Common excludes (regex)
EXCLUDE_REGEX='(\.git|\.venv|venv|__pycache__|\.mypy_cache|\.pytest_cache|build|dist)/'

# ------------------------------------------------------------
# colors (auto-disable if not a tty)
# ------------------------------------------------------------
if [ -t 1 ]; then
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BOLD="\033[1m"
  RESET="\033[0m"
  OK_SYM="✅"
  KO_SYM="❌"
else
  RED=""
  GREEN=""
  YELLOW=""
  BOLD=""
  RESET=""
  OK_SYM="OK"
  KO_SYM="KO"
fi

# ------------------------------------------------------------
# formatting helpers (42-like)
# ------------------------------------------------------------
line() { printf "%s\n" "=============================="; }
sep()  { printf "%s\n" "------------------------------"; }
h1()   { line; printf "%s\n" "$1"; line; }
kv()   { printf "%-12s %s\n" "$1" "$2"; }

ok_line() { printf "%b%s%b %s\n" "$GREEN" "$OK_SYM" "$RESET" "$1"; }
ko_line() { printf "%b%s%b %s\n" "$RED" "$KO_SYM" "$RESET" "$1"; }

# ------------------------------------------------------------
# tool checks
# ------------------------------------------------------------
need_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    ko_line "Missing tool: $1"
    printf "Install:\n  %s -m pip install -r tests_PYTHON/requirements-dev.txt\n" "$PYTHON_BIN"
    exit 1
  fi
}

need_tool flake8
need_tool mypy
need_tool pydocstyle

# ------------------------------------------------------------
# counting helpers (best-effort, tool-specific)
# ------------------------------------------------------------
count_flake8() {
  # flake8 prints one issue per line: path:line:col CODE message
  if [ ! -f "$1" ]; then echo 0; return; fi
  grep -E '^[^:]+:[0-9]+:[0-9]+: ' "$1" 2>/dev/null | wc -l | tr -d ' '
}

count_mypy() {
  # mypy issues: path:line: error|note: ...
  if [ ! -f "$1" ]; then echo 0; return; fi
  grep -E '^[^:]+:[0-9]+: (error|note): ' "$1" 2>/dev/null | wc -l | tr -d ' '
}

count_pydocstyle() {
  # pydocstyle issues usually start with: something.py:line ...
  if [ ! -f "$1" ]; then echo 0; return; fi
  grep -E '^[^:]+\.py:[0-9]+' "$1" 2>/dev/null | wc -l | tr -d ' '
}

# ------------------------------------------------------------
# run commands (capture stdout+stderr to logs AND to terminal)
# ------------------------------------------------------------
run_flake8() {
  h1 "flake8 — style & errors"
  cd "$PROJECT_ROOT" || return 2
  flake8 . --config "$SCRIPT_DIR/.flake8" 2>&1 | tee "$FLAKE8_LOG"
  return "${PIPESTATUS[0]}"
}

run_mypy() {
  h1 "mypy — type hints"
  cd "$PROJECT_ROOT" || return 2
  mypy . --config-file "$SCRIPT_DIR/mypy.ini" 2>&1 | tee "$MYPY_LOG"
  return "${PIPESTATUS[0]}"
}

run_pydocstyle() {
  h1 "pydocstyle — docstrings"
  cd "$PROJECT_ROOT" || return 2
  pydocstyle . --config "$SCRIPT_DIR/.pydocstyle" 2>&1 | tee "$PYDOC_LOG"
  return "${PIPESTATUS[0]}"
}

# ------------------------------------------------------------
# execution
# ------------------------------------------------------------
FAIL=0

FLAKE8_STATUS="NOTRUN"
MYPY_STATUS="NOTRUN"
PYDOC_STATUS="NOTRUN"

run_flake8
FLAKE8_RC=$?
if [ "$FLAKE8_RC" -eq 0 ]; then
  FLAKE8_STATUS="OK"
  ok_line "flake8 OK"
else
  FLAKE8_STATUS="FAIL($FLAKE8_RC)"
  ko_line "flake8 FAILED"
  FAIL=1
fi

run_mypy
MYPY_RC=$?
if [ "$MYPY_RC" -eq 0 ]; then
  MYPY_STATUS="OK"
  ok_line "mypy OK"
else
  MYPY_STATUS="FAIL($MYPY_RC)"
  ko_line "mypy FAILED"
  FAIL=1
fi

run_pydocstyle
PYDOC_RC=$?
if [ "$PYDOC_RC" -eq 0 ]; then
  PYDOC_STATUS="OK"
  ok_line "pydocstyle OK"
else
  PYDOC_STATUS="FAIL($PYDOC_RC)"
  ko_line "pydocstyle FAILED"
  FAIL=1
fi

# ------------------------------------------------------------
# summary (counts + log paths)
# ------------------------------------------------------------
FLAKE8_N="$(count_flake8 "$FLAKE8_LOG")"
MYPY_N="$(count_mypy "$MYPY_LOG")"
PYDOC_N="$(count_pydocstyle "$PYDOC_LOG")"

sep
printf "%bSUMMARY%b\n" "$BOLD" "$RESET"
sep

print_status() {
  local name="$1"
  local status="$2"
  local count="$3"

  if [[ "$status" == OK* ]]; then
    printf "%-12s %b%s %s%b (issues: %s)\n" \
      "$name:" "$GREEN" "$OK_SYM" "$status" "$RESET" "$count"
  else
    printf "%-12s %b%s %s%b (issues: %s)\n" \
      "$name:" "$RED" "$KO_SYM" "$status" "$RESET" "$count"
  fi
}

print_status "flake8" "$FLAKE8_STATUS" "$FLAKE8_N"
print_status "mypy" "$MYPY_STATUS" "$MYPY_N"
print_status "pydocstyle" "$PYDOC_STATUS" "$PYDOC_N"

sep
kv "logs:" "$LOG_DIR"
kv "last:" "flake8=$(basename "$FLAKE8_LOG") mypy=$(basename "$MYPY_LOG") pydocstyle=$(basename "$PYDOC_LOG")"
sep

# STRICT 42 verdict
if [ "$FAIL" -eq 0 ]; then
  printf "%b%s OK%b\n" "$GREEN" "$OK_SYM" "$RESET"
  exit 0
else
  printf "%b%s KO%b\n" "$RED" "$KO_SYM" "$RESET"
  exit 1
fi
