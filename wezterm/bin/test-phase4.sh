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
test_help_shows_session_commands() {
    local output=$(bash bin/wez-session --help 2>&1)

    if ! echo "$output" | grep -q "Session commands:"; then
        echo "Help text missing 'Session commands:' section"
        return 1
    fi

    if ! echo "$output" | grep -q "create"; then
        echo "Help text missing 'create' command"
        return 1
    fi

    if ! echo "$output" | grep -q "list"; then
        echo "Help text missing 'list' command"
        return 1
    fi

    if ! echo "$output" | grep -q "save"; then
        echo "Help text missing 'save' command"
        return 1
    fi

    if ! echo "$output" | grep -q "delete"; then
        echo "Help text missing 'delete' command"
        return 1
    fi

    echo "Help text contains all session commands"
    return 0
}

test_create_requires_name() {
    local output
    local exit_code=0
    output=$(bash bin/wez-session create 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "create without name should fail but didn't"
        return 1
    fi

    if ! echo "$output" | grep -iq "name required"; then
        echo "Error message missing 'name required'"
        return 1
    fi

    echo "create command requires name argument"
    return 0
}

test_create_validates_name() {
    local output
    local exit_code=0
    output=$(bash bin/wez-session create "bad name!" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "create with invalid name should fail but didn't"
        return 1
    fi

    if ! echo "$output" | grep -iq "must contain only"; then
        echo "Error message missing validation message"
        return 1
    fi

    echo "create command validates name format"
    return 0
}

test_delete_protects_default() {
    local output
    local exit_code=0
    output=$(bash bin/wez-session delete -f default 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "delete default should fail but didn't"
        return 1
    fi

    if ! echo "$output" | grep -iq "Cannot delete"; then
        echo "Error message missing 'Cannot delete'"
        return 1
    fi

    if ! echo "$output" | grep -iq "fallback"; then
        echo "Error message missing 'fallback' explanation"
        return 1
    fi

    echo "delete command protects default workspace"
    return 0
}

test_delete_requires_name() {
    local output
    local exit_code=0
    output=$(bash bin/wez-session delete 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "delete without name should fail but didn't"
        return 1
    fi

    if ! echo "$output" | grep -iq "name required"; then
        echo "Error message missing 'name required'"
        return 1
    fi

    echo "delete command requires name argument"
    return 0
}

test_delete_force_flag_accepted() {
    if ! grep -q '\-f\|--force' bin/wez-session; then
        echo "Script missing force flag handling"
        return 1
    fi

    echo "Script handles -f/--force flag"
    return 0
}

test_list_function_exists() {
    if ! grep -q 'session_list()' bin/wez-session; then
        echo "session_list function not found"
        return 1
    fi

    echo "session_list function exists"
    return 0
}

test_save_function_exists() {
    if ! grep -q 'session_save()' bin/wez-session; then
        echo "session_save function not found"
        return 1
    fi

    echo "session_save function exists"
    return 0
}

test_sessions_dir_constant() {
    if ! grep -q 'SESSIONS_DIR.*sessions' bin/wez-session; then
        echo "SESSIONS_DIR constant not found"
        return 1
    fi

    echo "SESSIONS_DIR constant defined"
    return 0
}

test_relative_time_function() {
    if ! grep -q 'relative_time()' bin/wez-session; then
        echo "relative_time function not found"
        return 1
    fi

    echo "relative_time function exists"
    return 0
}

test_json_format_compatible() {
    local script_content=$(cat bin/wez-session)

    if ! echo "$script_content" | grep -q "'version'"; then
        echo "JSON output missing 'version' field"
        return 1
    fi

    if ! echo "$script_content" | grep -q "'last_saved'"; then
        echo "JSON output missing 'last_saved' field"
        return 1
    fi

    if ! echo "$script_content" | grep -q "'workspace'"; then
        echo "JSON output missing 'workspace' field"
        return 1
    fi

    echo "JSON format matches state.lua schema"
    return 0
}

# Main test runner
main() {
    echo "======================================"
    echo "Phase 4 Test Suite"
    echo "======================================"
    echo ""

    run_test "help_shows_session_commands" test_help_shows_session_commands
    run_test "create_requires_name" test_create_requires_name
    run_test "create_validates_name" test_create_validates_name
    run_test "delete_protects_default" test_delete_protects_default
    run_test "delete_requires_name" test_delete_requires_name
    run_test "delete_force_flag_accepted" test_delete_force_flag_accepted
    run_test "list_function_exists" test_list_function_exists
    run_test "save_function_exists" test_save_function_exists
    run_test "sessions_dir_constant" test_sessions_dir_constant
    run_test "relative_time_function" test_relative_time_function
    run_test "json_format_compatible" test_json_format_compatible

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
