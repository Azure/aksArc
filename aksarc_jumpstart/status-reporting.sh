#!/bin/bash
# Shared status reporting and ARM-deployment error surfacing helpers.
#
# Source from a calling script:
#     source "$(dirname "$0")/status-reporting.sh"
#     init_execution_status "jumpstart.sh"
#
# After init_execution_status, the caller has access to:
#     print_execution_status
#     handle_error <step_name> <error_msg> [exit_code]
#     add_completed_step <step_name>
#     invoke_vm_script_deployment <step_name> <resource_group> <location> <vm_name> <script_uri> <inner_script>

# Required globals (callers can override START_TIME if needed).
EXECUTION_STATUS="InProgress"
SCRIPT_NAME=""
START_TIME=""
COMPLETED_STEPS=()
FAILED_STEP=""
ERROR_MESSAGE=""
EXIT_CODE=0

init_execution_status() {
    SCRIPT_NAME="$1"
    EXECUTION_STATUS="InProgress"
    START_TIME=$(date +'%Y-%m-%d %H:%M:%S')
    COMPLETED_STEPS=()
    FAILED_STEP=""
    ERROR_MESSAGE=""
    EXIT_CODE=0
}

print_execution_status() {
    local end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo ""
    echo "===== EXECUTION STATUS ====="
    echo "Status: $EXECUTION_STATUS"
    if [[ "$EXECUTION_STATUS" == "Failure" ]]; then
        echo "Failed Step: $FAILED_STEP"
        echo "Error Message: $ERROR_MESSAGE"
    fi
    echo "Exit Code: $EXIT_CODE"
    echo "Completed Steps: ${COMPLETED_STEPS[*]}"
    echo "Start Time: $START_TIME"
    echo "End Time: $end_time"
    echo "============================"
}

handle_error() {
    local step_name="$1"
    local error_msg="$2"
    local exit_code="${3:-1}"

    EXECUTION_STATUS="Failure"
    FAILED_STEP="$step_name"
    ERROR_MESSAGE="$error_msg"
    EXIT_CODE="$exit_code"

    print_execution_status
    exit "$exit_code"
}

add_completed_step() {
    COMPLETED_STEPS+=("$1")
}

# Deploy executescript-template.json and treat ANY of these as failure:
#   1. az deployment group create returned non-zero
#   2. Extension instance view shows ProvisioningState != succeeded
#   3. (Soft) Extension StdErr substatus is non-empty -> warn but don't fail
#
# `commandToExecute` is constructed identically to the pre-existing code path
# so this change does not alter what runs inside the VM -- it only adds a
# post-deploy inspection of the extension to catch failures the deployment
# exit code missed (the actual bug we are fixing).
#
# Args:
#   $1 step_name       (e.g. "ExecuteScript_deploymoc.ps1")
#   $2 resource_group
#   $3 location
#   $4 vm_name
#   $5 script_uri      (raw github URL)
#   $6 inner_script    (e.g. "deploymoc.ps1" or "deployappliance.ps1 -arg val")
#   $7 template_file   (optional, default ./configuration/executescript-template.json)
invoke_vm_script_deployment() {
    local step_name="$1"
    local resource_group="$2"
    local location="$3"
    local vm_name="$4"
    local script_uri="$5"
    local inner_script="$6"
    local template_file="${7:-./configuration/executescript-template.json}"

    local script_basename="${inner_script%% *}"          # first whitespace-delimited token
    local deployment_name="executescript-${vm_name}-${script_basename%.*}"
    local command_to_execute="powershell.exe -ExecutionPolicy Unrestricted -File ${inner_script}"

    echo "Executing ${command_to_execute} from ${script_uri} on VM ${vm_name}..."

    # Use `|| rc=$?` so the helper works correctly under `set -e` -- otherwise
    # a non-zero exit from `az` would terminate the script before we can
    # capture the exit code or inspect the extension instance view.
    local deployment_exit_code=0
    az deployment group create \
        --name "$deployment_name" \
        --resource-group "$resource_group" \
        --template-file "$template_file" \
        --parameters \
            location="$location" \
            vmName="$vm_name" \
            scriptFileUri="$script_uri" \
            commandToExecute="$command_to_execute" || deployment_exit_code=$?

    # Always inspect the extension instance view for ground truth.
    local instance_view=""
    local ext_lookup_exit_code=0
    instance_view=$(az vm extension show \
        --resource-group "$resource_group" \
        --vm-name "$vm_name" \
        --name CustomScriptExtension \
        --instance-view \
        --query instanceView \
        -o json 2>/dev/null) || ext_lookup_exit_code=$?

    local provisioning_state=""
    local status_message=""
    local std_out=""
    local std_err=""
    if [[ $ext_lookup_exit_code -eq 0 && -n "$instance_view" ]] && command -v jq >/dev/null 2>&1; then
        provisioning_state=$(echo "$instance_view" | jq -r '.statuses[]? | select(.code | startswith("ProvisioningState/")) | .code' | head -n1)
        status_message=$(echo "$instance_view" | jq -r '.statuses[]? | select(.code | startswith("ProvisioningState/")) | .message' | head -n1)
        std_out=$(echo "$instance_view" | jq -r '.substatuses[]? | select(.code | startswith("ComponentStatus/StdOut/")) | .message' | head -n1)
        std_err=$(echo "$instance_view" | jq -r '.substatuses[]? | select(.code | startswith("ComponentStatus/StdErr/")) | .message' | head -n1)
    fi

    local extension_failed=false
    if [[ -n "$provisioning_state" && "$provisioning_state" != *succeeded ]]; then
        extension_failed=true
    fi

    if [[ $deployment_exit_code -ne 0 || "$extension_failed" == "true" ]]; then
        local fail_exit_code=$deployment_exit_code
        if [[ $fail_exit_code -eq 0 ]]; then
            fail_exit_code=1
        fi
        local error_text="Failed to execute script '${inner_script}' on VM '${vm_name}' (step '${step_name}'). DeploymentExitCode=${deployment_exit_code}; ProvisioningState=${provisioning_state}; StatusMessage=${status_message}; StdErr=${std_err}; StdOut=${std_out}"
        handle_error "$step_name" "$error_text" "$fail_exit_code"
    fi

    if [[ -n "$std_err" ]]; then
        echo "WARNING: step '${step_name}' completed but extension StdErr was non-empty:"
        echo "$std_err"
    fi

    add_completed_step "$step_name"
}
