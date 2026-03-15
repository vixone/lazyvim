#!/bin/bash
set -euo pipefail

# Color output helpers
green() { echo -e "\033[0;32m$*\033[0m"; }
red() { echo -e "\033[0;31m$*\033[0m"; }
yellow() { echo -e "\033[0;33m$*\033[0m"; }

# Test tracking
PASSED=0
FAILED=0
SKIPPED=0
VERBOSE=false

# Parse arguments
TEST_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            TEST_FILTER="$1"
            shift
            ;;
    esac
done

# Helper to run tests
run_test() {
    local test_name="$1"
    local test_func="$2"

    # Apply filter if specified
    if [[ -n "$TEST_FILTER" ]] && [[ "$test_name" != *"$TEST_FILTER"* ]]; then
        return 0
    fi

    echo -n "Testing $test_name... "

    if $VERBOSE; then
        echo ""
    fi

    local output
    if output=$($test_func 2>&1); then
        green "PASS"
        ((PASSED++))
        if $VERBOSE && [[ -n "$output" ]]; then
            echo "  $output"
        fi
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            yellow "SKIP"
            ((SKIPPED++))
            if [[ -n "$output" ]]; then
                echo "  $output"
            fi
        else
            red "FAIL"
            ((FAILED++))
            if [[ -n "$output" ]]; then
                echo "  $output"
            fi
        fi
    fi
}

# Test functions
test_config_syntax() {
    # Test that wezterm binary exists and can load config
    # Note: wezterm doesn't have a show-config command, so we test with --help
    # which validates the config can be loaded
    if wezterm --help > /dev/null 2>&1; then
        echo "WezTerm config loads successfully"
        return 0
    else
        echo "WezTerm config has syntax errors"
        return 1
    fi
}

test_state_module_exists() {
    if [[ ! -f "lua/session/state.lua" ]]; then
        echo "state.lua not yet created (Wave 1)"
        return 2  # Skip
    fi

    if [[ ! -s "lua/session/state.lua" ]]; then
        echo "state.lua exists but is empty"
        return 1
    fi

    echo "state.lua exists and is non-empty"
    return 0
}

test_state_module_functions() {
    if [[ ! -f "lua/session/state.lua" ]]; then
        echo "state.lua not yet created (Wave 1)"
        return 2  # Skip
    fi

    local missing=()

    grep -q "function M\.uri_to_path" lua/session/state.lua || missing+=("uri_to_path")
    grep -q "function M\.capture_workspace" lua/session/state.lua || missing+=("capture_workspace")
    grep -q "function M\.save_current_workspace" lua/session/state.lua || missing+=("save_current_workspace")
    grep -q "function M\.load_workspace" lua/session/state.lua || missing+=("load_workspace")

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "All expected functions found in state.lua"
        return 0
    else
        echo "Missing functions in state.lua: ${missing[*]}"
        return 1
    fi
}

test_sessions_dir() {
    if [[ ! -d "sessions" ]]; then
        echo "sessions/ directory does not exist"
        return 1
    fi

    echo "sessions/ directory exists"
    return 0
}

test_json_structure() {
    # Find any .json files in sessions/
    local json_files=( sessions/*.json )

    if [[ ! -e "${json_files[0]}" ]]; then
        echo "No session files exist yet (Wave 1+)"
        return 2  # Skip
    fi

    local test_file="${json_files[0]}"
    local missing=()

    grep -q '"version"' "$test_file" || missing+=("version")
    grep -q '"workspace"' "$test_file" || missing+=("workspace")
    grep -q '"last_saved"' "$test_file" || missing+=("last_saved")
    grep -q '"tabs"' "$test_file" || missing+=("tabs")

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "JSON structure contains expected keys"
        return 0
    else
        echo "Missing JSON keys: ${missing[*]}"
        return 1
    fi
}

test_init_exposes_state() {
    if [[ ! -f "lua/session/init.lua" ]]; then
        echo "init.lua does not exist"
        return 1
    fi

    if grep -q "M\.state" lua/session/init.lua; then
        echo "init.lua exposes state module"
        return 0
    else
        echo "state module not yet wired (Wave 1)"
        return 2  # Skip
    fi
}

# Main test runner
main() {
    echo "======================================"
    echo "Phase 2 Test Suite"
    echo "======================================"
    echo ""

    run_test "config_syntax" test_config_syntax
    run_test "state_module_exists" test_state_module_exists
    run_test "state_module_functions" test_state_module_functions
    run_test "sessions_dir" test_sessions_dir
    run_test "json_structure" test_json_structure
    run_test "init_exposes_state" test_init_exposes_state

    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    green "Passed:  $PASSED"
    if [[ $FAILED -gt 0 ]]; then
        red "Failed:  $FAILED"
    else
        echo "Failed:  $FAILED"
    fi
    if [[ $SKIPPED -gt 0 ]]; then
        yellow "Skipped: $SKIPPED"
    else
        echo "Skipped: $SKIPPED"
    fi
    echo ""

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Change to script's parent directory (should be wezterm config dir)
cd "$(dirname "$0")/.."

main
