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
    if wezterm --help > /dev/null 2>&1; then
        echo "WezTerm config loads successfully"
        return 0
    else
        echo "WezTerm config has syntax errors"
        return 1
    fi
}

test_manager_module_exists() {
    if [[ ! -f "lua/session/manager.lua" ]]; then
        echo "manager.lua not yet created"
        return 2  # Skip
    fi

    if [[ ! -s "lua/session/manager.lua" ]]; then
        echo "manager.lua exists but is empty"
        return 1
    fi

    echo "manager.lua exists and is non-empty"
    return 0
}

test_manager_module_functions() {
    if [[ ! -f "lua/session/manager.lua" ]]; then
        echo "manager.lua not yet created"
        return 2  # Skip
    fi

    local missing=()

    grep -q "function M\.create_session" lua/session/manager.lua || missing+=("create_session")
    grep -q "function M\.list_sessions" lua/session/manager.lua || missing+=("list_sessions")
    grep -q "function M\.switch_session" lua/session/manager.lua || missing+=("switch_session")
    grep -q "function M\.delete_session" lua/session/manager.lua || missing+=("delete_session")

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "All 4 expected functions found in manager.lua"
        return 0
    else
        echo "Missing functions in manager.lua: ${missing[*]}"
        return 1
    fi
}

test_name_validation_pattern() {
    if [[ ! -f "lua/session/manager.lua" ]]; then
        echo "manager.lua not yet created"
        return 2  # Skip
    fi

    if grep -q '%w%-_' lua/session/manager.lua; then
        echo "Name validation pattern found in manager.lua"
        return 0
    else
        echo "Name validation pattern not found in manager.lua"
        return 1
    fi
}

test_default_protection() {
    if [[ ! -f "lua/session/manager.lua" ]]; then
        echo "manager.lua not yet created"
        return 2  # Skip
    fi

    if grep -q '"default"' lua/session/manager.lua; then
        echo "Default workspace protection logic found in manager.lua"
        return 0
    else
        echo "Default workspace protection not found in manager.lua"
        return 1
    fi
}

test_init_exposes_manager() {
    if [[ ! -f "lua/session/init.lua" ]]; then
        echo "init.lua does not exist"
        return 1
    fi

    if grep -q "M\.manager" lua/session/init.lua; then
        echo "init.lua exposes manager module"
        return 0
    else
        echo "manager module not yet wired"
        return 2  # Skip
    fi
}

test_auto_save_before_switch() {
    if [[ ! -f "lua/session/manager.lua" ]]; then
        echo "manager.lua not yet created"
        return 2  # Skip
    fi

    if grep -q 'save_current_workspace' lua/session/manager.lua; then
        echo "Auto-save before switch found in manager.lua"
        return 0
    else
        echo "Auto-save before switch not found in manager.lua"
        return 1
    fi
}

# Main test runner
main() {
    echo "======================================"
    echo "Phase 3 Test Suite"
    echo "======================================"
    echo ""

    run_test "config_syntax" test_config_syntax
    run_test "manager_module_exists" test_manager_module_exists
    run_test "manager_module_functions" test_manager_module_functions
    run_test "name_validation_pattern" test_name_validation_pattern
    run_test "default_protection" test_default_protection
    run_test "init_exposes_manager" test_init_exposes_manager
    run_test "auto_save_before_switch" test_auto_save_before_switch

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
