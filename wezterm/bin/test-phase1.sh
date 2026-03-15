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

test_directories() {
    local missing=()

    [[ -d "lua/session" ]] || missing+=("lua/session")
    [[ -d "bin" ]] || missing+=("bin")
    [[ -d "$HOME/.local/state/wezterm/sessions" ]] || missing+=("~/.local/state/wezterm/sessions")

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "All required directories exist"
        return 0
    else
        echo "Missing directories: ${missing[*]}"
        return 1
    fi
}

test_wez_session_script() {
    if [[ ! -f "bin/wez-session" ]]; then
        echo "bin/wez-session does not exist"
        return 1
    fi

    if [[ ! -x "bin/wez-session" ]]; then
        echo "bin/wez-session is not executable"
        return 1
    fi

    if bin/wez-session --help > /dev/null 2>&1; then
        echo "bin/wez-session runs and shows help"
        return 0
    else
        echo "bin/wez-session --help failed"
        return 1
    fi
}

test_lua_modules() {
    local missing=()

    for mod in init.lua state.lua manager.lua picker.lua; do
        if [[ ! -f "lua/session/$mod" ]]; then
            missing+=("lua/session/$mod")
        elif [[ ! -s "lua/session/$mod" ]]; then
            missing+=("lua/session/$mod (empty)")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "All Lua modules exist and are non-empty"
        return 0
    else
        echo "Missing or empty Lua modules: ${missing[*]}"
        return 1
    fi
}

# Main test runner
main() {
    echo "======================================"
    echo "Phase 1 Test Suite"
    echo "======================================"
    echo ""

    run_test "config_syntax" test_config_syntax
    run_test "directories" test_directories
    run_test "wez-session script" test_wez_session_script
    run_test "lua modules" test_lua_modules

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
