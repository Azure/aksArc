#!/bin/bash
# Test harness for status-reporting.sh.
#
# Mocks the `az` command so each scenario can be exercised without a live
# Azure subscription. Run with:
#   bash ./tests/test-status-reporting.sh

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
helpers="$(cd "$here/.." && pwd)/status-reporting.sh"

if ! command -v jq >/dev/null 2>&1; then
    echo "SKIP: jq not installed (required for invoke_vm_script_deployment)"
    exit 0
fi

fail_count=0

# Run a single scenario in a subshell so the `az` mock and global state are
# isolated. Captures combined stdout/stderr and exit code, then asserts.
run_scenario() {
    local name="$1"
    local az_mock_body="$2"
    local expected_exit="$3"
    local expected_substring="${4:-}"

    local script
    script=$(cat <<EOF
set +e
az() {
$az_mock_body
}
export -f az 2>/dev/null || true
source "$helpers"
init_execution_status "test"
invoke_vm_script_deployment \
    "TestStep" \
    "rg" \
    "eastus" \
    "vm" \
    "https://example/script.ps1" \
    "script.ps1"
EXECUTION_STATUS="Success"
print_execution_status
EOF
)

    local output
    output=$(bash -c "$script" 2>&1)
    local actual_exit=$?

    local passed=true
    local reasons=()
    if [[ $actual_exit -ne $expected_exit ]]; then
        passed=false
        reasons+=("exit code expected=$expected_exit actual=$actual_exit")
    fi
    if [[ -n "$expected_substring" ]] && ! echo "$output" | grep -qF -- "$expected_substring"; then
        passed=false
        reasons+=("output missing expected substring '$expected_substring'")
    fi

    if [[ "$passed" == "true" ]]; then
        echo "PASS  $name"
    else
        echo "FAIL  $name"
        for r in "${reasons[@]}"; do echo "      $r"; done
        echo "      ---- output ----"
        while IFS= read -r line; do echo "      $line"; done <<<"$output"
        fail_count=$((fail_count + 1))
    fi
}

# --- Scenario 1: deployment success + extension success + clean stderr ----
mock1='
    local is_dep=0 is_ext=0
    for arg in "$@"; do
        if [[ "$arg" == "deployment" ]]; then is_dep=1; fi
        if [[ "$arg" == "extension" ]]; then is_ext=1; fi
    done
    if [[ "${is_dep:-0}" == "1" ]]; then
        echo "{}"; return 0
    fi
    if [[ "${is_ext:-0}" == "1" ]]; then
        echo "{\"statuses\":[{\"code\":\"ProvisioningState/succeeded\",\"level\":\"Info\",\"message\":\"Enable succeeded\"}],\"substatuses\":[{\"code\":\"ComponentStatus/StdOut/succeeded\",\"message\":\"all good\"},{\"code\":\"ComponentStatus/StdErr/succeeded\",\"message\":\"\"}]}"
        return 0
    fi
    return 0
'
run_scenario "success: deploy ok + extension succeeded + empty stderr" \
    "$mock1" 0 "Status: Success"

# --- Scenario 2: deployment success + extension failed (silent failure!) ----
mock2='
    local is_dep=0 is_ext=0
    for arg in "$@"; do
        if [[ "$arg" == "deployment" ]]; then is_dep=1; fi
        if [[ "$arg" == "extension" ]]; then is_ext=1; fi
    done
    if [[ "${is_dep:-0}" == "1" ]]; then
        echo "{}"; return 0
    fi
    if [[ "${is_ext:-0}" == "1" ]]; then
        echo "{\"statuses\":[{\"code\":\"ProvisioningState/failed\",\"level\":\"Error\",\"message\":\"Enable failed: VM script returned non-zero\"}],\"substatuses\":[{\"code\":\"ComponentStatus/StdOut/failed\",\"message\":\"some progress output\"},{\"code\":\"ComponentStatus/StdErr/failed\",\"message\":\"INNER_SCRIPT_ERROR: Install-Module failed\"}]}"
        return 0
    fi
    return 0
'
run_scenario "silent-failure: deploy ok + extension Failed -> caught" \
    "$mock2" 1 "INNER_SCRIPT_ERROR: Install-Module failed"

# --- Scenario 3: deployment failed (loud failure) ----
mock3='
    local is_dep=0 is_ext=0
    for arg in "$@"; do
        if [[ "$arg" == "deployment" ]]; then is_dep=1; fi
        if [[ "$arg" == "extension" ]]; then is_ext=1; fi
    done
    if [[ "${is_dep:-0}" == "1" ]]; then
        echo "simulated deployment error" >&2; return 2
    fi
    if [[ "${is_ext:-0}" == "1" ]]; then
        echo "{\"statuses\":[{\"code\":\"ProvisioningState/failed\",\"level\":\"Error\",\"message\":\"timeout\"}],\"substatuses\":[{\"code\":\"ComponentStatus/StdErr/failed\",\"message\":\"timed out waiting for VM\"}]}"
        return 0
    fi
    return 0
'
run_scenario "deploy-failure: deploy non-zero -> caught with extension detail" \
    "$mock3" 2 "timed out waiting for VM"

# --- Scenario 4: deployment success + extension success + non-empty stderr (warn) ----
mock4='
    local is_dep=0 is_ext=0
    for arg in "$@"; do
        if [[ "$arg" == "deployment" ]]; then is_dep=1; fi
        if [[ "$arg" == "extension" ]]; then is_ext=1; fi
    done
    if [[ "${is_dep:-0}" == "1" ]]; then
        echo "{}"; return 0
    fi
    if [[ "${is_ext:-0}" == "1" ]]; then
        echo "{\"statuses\":[{\"code\":\"ProvisioningState/succeeded\",\"level\":\"Info\",\"message\":\"Enable succeeded\"}],\"substatuses\":[{\"code\":\"ComponentStatus/StdOut/succeeded\",\"message\":\"ok\"},{\"code\":\"ComponentStatus/StdErr/succeeded\",\"message\":\"WARNING: deprecated cmdlet\"}]}"
        return 0
    fi
    return 0
'
run_scenario "noisy-success: succeeded + non-empty stderr -> warn but pass" \
    "$mock4" 0 "WARNING: deprecated cmdlet"

# --- Scenario 5: extension show itself fails ----
mock5='
    local is_dep=0 is_ext=0
    for arg in "$@"; do
        if [[ "$arg" == "deployment" ]]; then is_dep=1; fi
        if [[ "$arg" == "extension" ]]; then is_ext=1; fi
    done
    if [[ "${is_dep:-0}" == "1" ]]; then
        echo "{}"; return 0
    fi
    if [[ "${is_ext:-0}" == "1" ]]; then
        return 1
    fi
    return 0
'
run_scenario "extension-show-fails: deploy ok + view unfetchable -> pass" \
    "$mock5" 0 "Status: Success"

if [[ $fail_count -gt 0 ]]; then
    echo
    echo "$fail_count scenario(s) failed."
    exit 1
fi

echo
echo "All scenarios passed."
exit 0
