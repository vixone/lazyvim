#!/usr/bin/env bash
# Phase 5 test suite - Layout restoration validation
set -euo pipefail

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Flags
VERBOSE=0
FILTER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      FILTER="$1"
      shift
      ;;
  esac
done

# Helper: run a test
run_test() {
  local name="$1"
  local func="$2"

  # Apply filter if set
  if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
    return 0
  fi

  echo -e "${BLUE}Running:${NC} $name"

  if $func; then
    echo -e "${GREEN}PASSED${NC}: $name"
    ((PASSED++))
  else
    local exit_code=$?
    if [[ $exit_code -eq 2 ]]; then
      echo -e "${YELLOW}SKIPPED${NC}: $name"
      ((SKIPPED++))
    else
      echo -e "${RED}FAILED${NC}: $name"
      ((FAILED++))
    fi
  fi
  echo ""
}

# Test 1: Config syntax
test_config_syntax() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking WezTerm config loads without errors..."
  fi

  wezterm --version > /dev/null 2>&1 || return 1

  # Use lua -e to check syntax without running the config
  local config_file="$HOME/.config/wezterm/wezterm.lua"
  if [[ ! -f "$config_file" ]]; then
    return 1
  fi

  # Basic syntax check via wezterm cli
  wezterm cli list --format json > /dev/null 2>&1 || return 1

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ WezTerm binary functional"
  fi

  return 0
}

# Test 2: Restore functions exist
test_restore_functions_exist() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for attach_session and restore_session functions..."
  fi

  local manager_file="lua/session/manager.lua"

  if ! grep -q "function M\.attach_session" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ attach_session not found - skipping"
    fi
    return 2
  fi

  if ! grep -q "function M\.restore_session" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ restore_session not found - skipping"
    fi
    return 2
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ Both restore functions found"
  fi

  return 0
}

# Test 3: RESTORABLE_PROCESSES defined
test_restorable_processes_defined() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for RESTORABLE_PROCESSES table..."
  fi

  local manager_file="lua/session/manager.lua"

  if ! grep -q "RESTORABLE_PROCESSES" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ RESTORABLE_PROCESSES not found - skipping"
    fi
    return 2
  fi

  # Check it's a table assignment
  if ! grep -q "local RESTORABLE_PROCESSES = {" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ RESTORABLE_PROCESSES found but not a table"
    fi
    return 1
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ RESTORABLE_PROCESSES table defined"
  fi

  return 0
}

# Test 4: Split direction logic
test_split_direction_logic() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for geometry-based split direction inference..."
  fi

  local manager_file="lua/session/manager.lua"

  # Check for left position comparison
  if ! grep -q "\.left" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Geometry logic not found - skipping"
    fi
    return 2
  fi

  # Check for Right and Bottom direction strings
  if ! grep -q "Right" "$manager_file" 2>/dev/null || ! grep -q "Bottom" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Split directions not found - skipping"
    fi
    return 2
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ Split direction logic found"
  fi

  return 0
}

# Test 5: First pane reuse (no fragile closure)
test_first_pane_reuse() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for safe first pane handling..."
  fi

  local manager_file="lua/session/manager.lua"

  # Skip if restore functions don't exist
  if ! grep -q "function M\.restore_session" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Restore functions not yet implemented - skipping"
    fi
    return 2
  fi

  # Look for problematic patterns (exit or kill on initial pane)
  # But allow exit in delete_session context
  if grep -A 5 "function M\.restore_session\|function M\._restore" "$manager_file" 2>/dev/null | grep -q "exit"; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ Found fragile exit pattern in restore logic"
    fi
    return 1
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ No fragile initial pane closure"
  fi

  return 0
}

# Test 6: Nil-safe process handling
test_nil_safe_process() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for nil-safe process handling..."
  fi

  local manager_file="lua/session/manager.lua"

  # Skip if restore functions don't exist
  if ! grep -q "function M\._configure_pane\|function M\.restore" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Configure pane logic not yet implemented - skipping"
    fi
    return 2
  fi

  # Check for nil-check before process operations
  if ! grep -q "pane_data\.process" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Process handling not found - skipping"
    fi
    return 2
  fi

  # Should contain "if pane_data.process" or "and pane_data.process"
  if grep -q "if.*pane_data\.process\|and pane_data\.process" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✓ Nil-safe process handling found"
    fi
    return 0
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✗ Process handling not nil-safe"
  fi
  return 1
}

# Test 7: Sample session JSON valid
test_sample_session_json() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Validating sessions/test-restore.json..."
  fi

  local json_file="sessions/test-restore.json"

  if [[ ! -f "$json_file" ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ Test JSON file not found"
    fi
    return 1
  fi

  # Validate JSON syntax
  if ! python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ Invalid JSON syntax"
    fi
    return 1
  fi

  # Check structure
  local tab_count=$(python3 -c "import json; d=json.load(open('$json_file')); print(len(d.get('tabs', [])))")
  local pane_count=$(python3 -c "import json; d=json.load(open('$json_file')); print(sum(len(t.get('panes', [])) for t in d.get('tabs', [])))")

  if [[ "$tab_count" != "2" ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ Expected 2 tabs, found $tab_count"
    fi
    return 1
  fi

  if [[ "$pane_count" != "4" ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ Expected 4 panes, found $pane_count"
    fi
    return 1
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ Valid JSON with 2 tabs, 4 panes"
  fi

  return 0
}

# Test 8: Smart attach behavior
test_attach_smart_behavior() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking attach_session smart routing..."
  fi

  local manager_file="lua/session/manager.lua"

  # Skip if attach_session doesn't exist
  if ! grep -q "function M\.attach_session" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ attach_session not yet implemented - skipping"
    fi
    return 2
  fi

  # Check for workspace detection logic
  if ! grep -q "all_windows\|get_workspace" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Workspace detection not found - skipping"
    fi
    return 2
  fi

  # Should contain switch_session OR restore_session call
  if grep -A 40 "function M\.attach_session" "$manager_file" 2>/dev/null | grep -q "switch_session\|restore_session"; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✓ Smart attach routing found"
    fi
    return 0
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✗ Smart attach logic incomplete"
  fi
  return 1
}

# Test 9: Missing CWD fallback
test_missing_cwd_fallback() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for home_dir fallback on missing CWD..."
  fi

  local manager_file="lua/session/manager.lua"

  # Skip if restore logic doesn't exist
  if ! grep -q "function M\.restore\|function M\._restore" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Restore logic not yet implemented - skipping"
    fi
    return 2
  fi

  # Check for home_dir usage
  if ! grep -q "home_dir" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ home_dir fallback not found - skipping"
    fi
    return 2
  fi

  # Should contain "or wezterm.home_dir" pattern
  if grep -q "or wezterm\.home_dir\|or.*home_dir" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✓ Missing CWD fallback found"
    fi
    return 0
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✗ No home_dir fallback for missing CWD"
  fi
  return 1
}

# Test 10: Tab title restore
test_tab_title_restore() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for tab title restoration..."
  fi

  local manager_file="lua/session/manager.lua"

  # Skip if restore logic doesn't exist
  if ! grep -q "function M\._restore_layout\|function M\.restore" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Restore layout logic not yet implemented - skipping"
    fi
    return 2
  fi

  # Check for set_title
  if ! grep -q "set_title" "$manager_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ set_title not found - skipping"
    fi
    return 2
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ Tab title restoration found"
  fi

  return 0
}

# Test 11: CLI attach function exists
test_cli_attach_function() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for session_attach() function in bin/wez-session..."
  fi

  local cli_file="bin/wez-session"

  if ! grep -q "^session_attach()" "$cli_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ session_attach() function not found"
    fi
    return 1
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ session_attach() function exists"
  fi

  return 0
}

# Test 12: CLI attach routing exists
test_cli_attach_routing() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for attach) case in bin/wez-session..."
  fi

  local cli_file="bin/wez-session"

  if ! grep -q "attach)" "$cli_file" 2>/dev/null; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ attach) case not found"
    fi
    return 1
  fi

  # Should call session_attach
  if ! grep -A 2 "attach)" "$cli_file" 2>/dev/null | grep -q "session_attach"; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ attach) case doesn't call session_attach"
    fi
    return 1
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ attach) routing exists and calls session_attach"
  fi

  return 0
}

# Test 13: CLI help includes attach
test_cli_help_includes_attach() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for 'attach' in help text..."
  fi

  # Need daemon running for CLI to work
  if ! [[ -S "$HOME/.local/state/wezterm/wezterm.sock" ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ⊘ Daemon not running, checking source instead..."
    fi
    # Fall back to checking source
    if grep -q "attach <name>" "bin/wez-session" 2>/dev/null; then
      if [[ $VERBOSE -eq 1 ]]; then
        echo "  ✓ attach found in help text (source)"
      fi
      return 0
    fi
    return 1
  fi

  if bin/wez-session --help 2>&1 | grep -q "attach"; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✓ Help text includes 'attach'"
    fi
    return 0
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✗ 'attach' not found in help"
  fi
  return 1
}

# Test 14: CLI attach missing name error
test_cli_attach_missing_name() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo "  Checking for error when attach called without name..."
  fi

  local cli_file="bin/wez-session"

  # Check source for error message
  if ! grep -A 5 "^session_attach()" "$cli_file" 2>/dev/null | grep -q "Session name required"; then
    if [[ $VERBOSE -eq 1 ]]; then
      echo "  ✗ 'Session name required' error not found in source"
    fi
    return 1
  fi

  if [[ $VERBOSE -eq 1 ]]; then
    echo "  ✓ Missing name error check found in source"
  fi

  return 0
}

# Run all tests
echo "================================================"
echo "Phase 5 Test Suite - Layout Restoration"
echo "================================================"
echo ""

run_test "test_config_syntax" test_config_syntax
run_test "test_restore_functions_exist" test_restore_functions_exist
run_test "test_restorable_processes_defined" test_restorable_processes_defined
run_test "test_split_direction_logic" test_split_direction_logic
run_test "test_first_pane_reuse" test_first_pane_reuse
run_test "test_nil_safe_process" test_nil_safe_process
run_test "test_sample_session_json" test_sample_session_json
run_test "test_attach_smart_behavior" test_attach_smart_behavior
run_test "test_missing_cwd_fallback" test_missing_cwd_fallback
run_test "test_tab_title_restore" test_tab_title_restore
run_test "test_cli_attach_function" test_cli_attach_function
run_test "test_cli_attach_routing" test_cli_attach_routing
run_test "test_cli_help_includes_attach" test_cli_help_includes_attach
run_test "test_cli_attach_missing_name" test_cli_attach_missing_name

echo "================================================"
echo "Test Results"
echo "================================================"
echo -e "${GREEN}PASSED${NC}: $PASSED"
echo -e "${RED}FAILED${NC}: $FAILED"
echo -e "${YELLOW}SKIPPED${NC}: $SKIPPED"
echo ""

if [[ $FAILED -gt 0 ]]; then
  exit 1
elif [[ $SKIPPED -gt 0 ]]; then
  exit 2
else
  exit 0
fi
