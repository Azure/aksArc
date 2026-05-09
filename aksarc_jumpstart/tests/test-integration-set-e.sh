#!/bin/bash
# Integration test that simulates jumpstart.sh end-to-end with set -e enabled
# and an `az` mock. Validates that:
#   1. ARM deployment failures cause the script to exit non-zero AND print the
#      EXECUTION STATUS block (the original silent-failure bug)
#   2. CustomScriptExtension silent failures (deployment exit 0 but extension
#      ProvisioningState=failed) are caught
#
# Run with: bash ./tests/test-integration-set-e.sh

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
helpers="$(cd "$here/.." && pwd)/status-reporting.sh"

fail_count=0

if ! command -v jq >/dev/null 2>&1; then
    echo "SKIP: jq not installed"
    exit 0
fi

# Simulate the relevant slice of jumpstart.sh under set -e: az group create
# fails -> we expect Status: Failure block + non-zero exit, NOT silent death.
test_arm_failure_under_set_e() {
    local script
    script=$(cat <<EOF
set -e
set -o pipefail
az() {
    if [[ "\$1" == "group" && "\$2" == "create" ]]; then
        echo "ERROR: simulated quota exceeded" >&2
        return 1
    fi
    return 0
}
source "$helpers"
init_execution_status "test-integration"
az group create --name foo --location eastus \
    || handle_error "CreateResourceGroup" "Failed to create resource group 'foo'" \$?
add_completed_step "CreateResourceGroup"
EXECUTION_STATUS="Success"
print_execution_status
EOF
)
    local output
    output=$(bash -c "$script" 2>&1)
    local rc=$?
    local passed=true
    local reasons=()
    if [[ $rc -eq 0 ]]; then
        passed=false
        reasons+=("expected non-zero exit, got $rc")
    fi
    if ! echo "$output" | grep -qF "Status: Failure"; then
        passed=false
        reasons+=("EXECUTION STATUS block not printed (silent death!)")
    fi
    if ! echo "$output" | grep -qF "CreateResourceGroup"; then
        passed=false
        reasons+=("FailedStep not in output")
    fi
    if [[ "$passed" == "true" ]]; then
        echo "PASS  set -e: ARM failure prints status block and exits non-zero"
    else
        echo "FAIL  set -e: ARM failure prints status block and exits non-zero"
        for r in "${reasons[@]}"; do echo "      $r"; done
        echo "      ---- output ----"
        while IFS= read -r line; do echo "      $line"; done <<<"$output"
        fail_count=$((fail_count + 1))
    fi
}

# Same test but for the silent-failure case: deployment returns 0 but the
# extension instance view shows ProvisioningState=failed. The wrapped helper
# must still trigger a Failure status under set -e.
test_silent_extension_failure_under_set_e() {
    local script
    script=$(cat <<EOF
set -e
set -o pipefail
az() {
    local is_dep=0 is_ext=0
    for arg in "\$@"; do
        [[ "\$arg" == "deployment" ]] && is_dep=1
        [[ "\$arg" == "extension" ]] && is_ext=1
    done
    if [[ \$is_dep -eq 1 ]]; then echo "{}"; return 0; fi
    if [[ \$is_ext -eq 1 ]]; then
        echo '{"statuses":[{"code":"ProvisioningState/failed","message":"VM script returned non-zero"}],"substatuses":[{"code":"ComponentStatus/StdErr/failed","message":"INNER ERROR: missing module"}]}'
        return 0
    fi
    return 0
}
source "$helpers"
init_execution_status "test-integration"
invoke_vm_script_deployment "ExecuteScript_test" "rg" "eastus" "vm" "https://example/x.ps1" "x.ps1"
EXECUTION_STATUS="Success"
print_execution_status
EOF
)
    local output
    output=$(bash -c "$script" 2>&1)
    local rc=$?
    local passed=true
    local reasons=()
    if [[ $rc -eq 0 ]]; then
        passed=false
        reasons+=("expected non-zero exit, got $rc (silent failure not caught)")
    fi
    if ! echo "$output" | grep -qF "INNER ERROR: missing module"; then
        passed=false
        reasons+=("extension StdErr not surfaced in output")
    fi
    if [[ "$passed" == "true" ]]; then
        echo "PASS  set -e: silent extension failure caught and surfaced"
    else
        echo "FAIL  set -e: silent extension failure caught and surfaced"
        for r in "${reasons[@]}"; do echo "      $r"; done
        echo "      ---- output ----"
        while IFS= read -r line; do echo "      $line"; done <<<"$output"
        fail_count=$((fail_count + 1))
    fi
}

test_arm_failure_under_set_e
test_silent_extension_failure_under_set_e

if [[ $fail_count -gt 0 ]]; then
    echo
    echo "$fail_count integration test(s) failed."
    exit 1
fi
echo
echo "All integration tests passed."
exit 0
