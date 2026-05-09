#!/usr/bin/env python3
"""
AKS Arc Jumpstart — Phase 2 Deployment Orchestrator

Uses 'az vm run-command create' with --run-as-user for reliable, debuggable
execution. Each step runs as the admin user directly (no scheduled tasks).

Key improvements over the CSE-based approach:
  - No SYSTEM context / scheduled task hacks
  - Inline scripts — no GitHub push required before testing
  - Each step is independently retryable (--start-from N)
  - Full stdout/stderr captured and displayed locally
  - Configurable timeouts per step

Usage:
    python deploy_phase2.py --rg jumpstart-mn-rg15 --location eastus2 \
        --subscription <sub-id> --password 'JumpStart@2026!'

    # Resume from step 3:
    python deploy_phase2.py ... --start-from 3
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time


# ──────────────────────────────────────────────────────────────────────
# Azure CLI wrapper
# ──────────────────────────────────────────────────────────────────────

import shutil

# On Windows, az CLI is a .CMD wrapper that calls Python.
# Calling .CMD files via subprocess is fragile (cmd.exe arg escaping).
# Instead, call the underlying Python directly.
_az_cmd_path = shutil.which("az") or ""
if sys.platform == "win32" and _az_cmd_path.lower().endswith(".cmd"):
    _az_python = os.path.join(os.path.dirname(_az_cmd_path), "..", "python.exe")
    _az_python = os.path.normpath(_az_python)
    AZ_CMD = [_az_python, "-IBm", "azure.cli"]
else:
    AZ_CMD = ["az"]


def _run_az(cmd_list):
    """Run az CLI command. cmd_list should start with AZ_CMD prefix."""
    return subprocess.run(cmd_list, capture_output=True, text=True)


def az(*args, check=True):
    """Run an az CLI command, return parsed JSON or raw string."""
    cmd = AZ_CMD + list(args) + ["--output", "json"]
    r = _run_az(cmd)
    if check and r.returncode != 0:
        raise RuntimeError(f"az {' '.join(args[:4])}… failed:\n{r.stderr.strip()}")
    if r.stdout.strip():
        try:
            return json.loads(r.stdout)
        except json.JSONDecodeError:
            return r.stdout.strip()
    return None


def az_tsv(*args, check=True):
    """Run az CLI, return plain text output (tsv)."""
    cmd = AZ_CMD + list(args) + ["--output", "tsv"]
    r = _run_az(cmd)
    if check and r.returncode != 0:
        raise RuntimeError(f"az {' '.join(args[:4])}… failed:\n{r.stderr.strip()}")
    return r.stdout.strip()


# ──────────────────────────────────────────────────────────────────────
# VM command runner — uses managed run commands
# ──────────────────────────────────────────────────────────────────────

class VMRunner:
    """Execute PowerShell scripts on an Azure VM via managed run commands."""

    def __init__(self, rg, vm, user, password):
        self.rg = rg
        self.vm = vm
        self.user = user
        self.password = password

    def execute(self, name: str, script: str, timeout: int = 1800,
                run_as_user: bool = False) -> str:
        """Run a PowerShell script on the VM.  Returns stdout on success."""
        cmd_name = f"step-{name}"

        # Write script to temp file (avoids shell quoting nightmares)
        fd, script_path = tempfile.mkstemp(suffix=".ps1", prefix=f"{name}-")
        try:
            with os.fdopen(fd, "w") as f:
                f.write(script)

            # Delete any leftover run-command with the same name
            _run_az(
                AZ_CMD + ["vm", "run-command", "delete",
                 "--resource-group", self.rg, "--vm-name", self.vm,
                 "--name", cmd_name, "--yes", "--no-wait", "--output", "none"],
            )
            time.sleep(5)

            print(f"  ▸ Creating run-command '{cmd_name}' (timeout {timeout}s)…")
            create_args = AZ_CMD + [
                "vm", "run-command", "create",
                "--resource-group", self.rg,
                "--vm-name", self.vm,
                "--name", cmd_name,
                "--script", f"@{script_path}",
                "--timeout-in-seconds", str(timeout),
                "--async-execution", "true",
                "--output", "none",
            ]
            if run_as_user:
                create_args += ["--run-as-user", self.user,
                                "--run-as-password", self.password]
            r = _run_az(create_args)
            if r.returncode != 0:
                raise RuntimeError(f"Failed to create run-command: {r.stderr.strip()}")

            # Poll until finished
            return self._poll(cmd_name, timeout)

        finally:
            os.unlink(script_path)

    def _poll(self, cmd_name: str, timeout: int) -> str:
        start = time.time()
        last_state = ""
        while True:
            time.sleep(15)
            elapsed = int(time.time() - start)

            try:
                status = az(
                    "vm", "run-command", "show",
                    "--resource-group", self.rg,
                    "--vm-name", self.vm,
                    "--name", cmd_name,
                    "--instance-view",
                )
            except RuntimeError:
                # transient show failure, retry
                continue

            prov = status.get("provisioningState", "Unknown")
            iv = status.get("instanceView", {})
            exec_state = iv.get("executionState", "")

            state_str = f"{prov}/{exec_state}" if exec_state else prov
            if state_str != last_state:
                m, s = divmod(elapsed, 60)
                print(f"  ⏳ {state_str} ({m}m{s:02d}s)")
                last_state = state_str

            # Terminal states
            if prov == "Failed" and not exec_state:
                self._cleanup(cmd_name)
                raise RuntimeError("Run-command provisioning failed")

            if exec_state in ("Succeeded", "Failed", "TimedOut"):
                stdout = iv.get("output", "")
                stderr = iv.get("error", "")

                if exec_state != "Succeeded":
                    self._dump_output("STDOUT", stdout)
                    self._dump_output("STDERR", stderr)
                    self._cleanup(cmd_name)
                    raise RuntimeError(
                        f"Step failed (executionState={exec_state})"
                    )

                self._cleanup(cmd_name)
                return stdout

            if elapsed > timeout + 120:
                self._cleanup(cmd_name)
                raise RuntimeError(f"Timed out after {elapsed}s")

    def _cleanup(self, cmd_name):
        _run_az(
            AZ_CMD + ["vm", "run-command", "delete",
             "--resource-group", self.rg, "--vm-name", self.vm,
             "--name", cmd_name, "--yes", "--no-wait", "--output", "none"],
        )

    @staticmethod
    def _dump_output(label, text):
        if not text:
            return
        lines = text.strip().splitlines()
        print(f"\n  ── {label} ({len(lines)} lines) ──")
        # Show last 40 lines
        for line in lines[-40:]:
            print(f"  │ {line}")


# ──────────────────────────────────────────────────────────────────────
# Step scripts (inline PowerShell)
# ──────────────────────────────────────────────────────────────────────

# Preamble: ensure az CLI is in PATH (SYSTEM context may not have it)
PS_PREAMBLE = r"""
# Ensure az CLI is in PATH
$azPaths = @(
    'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin',
    'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin'
)
foreach ($p in $azPaths) {
    if ((Test-Path $p) -and ($env:Path -notlike "*$p*")) {
        $env:Path = "$p;$env:Path"
    }
}
"""

def script_install_modules(arc_hci_version):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Installing PowerShell modules ==='
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
Install-Module -Name ArcHci -Repository PSGallery -Force -Confirm:$false -RequiredVersion {arc_hci_version}
Write-Host 'ArcHci module installed.'

Write-Host '=== Registering Azure providers ==='
$providers = @(
    'Microsoft.Kubernetes','Microsoft.KubernetesConfiguration',
    'Microsoft.ExtendedLocation','Microsoft.ResourceConnector',
    'Microsoft.HybridConnectivity','Microsoft.HybridContainerService'
)
foreach ($p in $providers) {{
    az provider register --namespace $p --wait 2>&1 | Out-Null
    Write-Host "  Registered $p"
}}

Write-Host '=== Installing Azure CLI extensions ==='
$exts = @('k8s-extension','customlocation','aksarc','connectedk8s','arcappliance','stack-hci-vm')
foreach ($e in $exts) {{
    az extension add --name $e --upgrade --yes 2>&1 | Out-Null
    Write-Host "  Installed $e"
}}

Write-Host 'DONE: All modules and extensions installed.'
"""


def script_generate_config(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'

$workDir = '{cfg["work_dir"]}'
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

# Determine MOC cloud agent endpoint
$cloudFqdn = $null
if (Get-Command Get-Cluster -ErrorAction SilentlyContinue) {{
    $c = Get-Cluster -ErrorAction SilentlyContinue
    # Multi-node: MOC's cloudServiceIP is 10.0.0.101 (cluster IP is .100)
    if ($c) {{ $cloudFqdn = '10.0.0.101' }}
}}
if (-not $cloudFqdn) {{
    $cloudFqdn = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {{ $_.IPAddress -like '10.0.0.*' -and $_.PrefixOrigin -ne 'WellKnown' }} |
        Select-Object -First 1).IPAddress
}}
Write-Host "cloudFqdn: $cloudFqdn"

Import-Module ArcHci -WarningAction SilentlyContinue

Write-Host '=== Generating appliance config files ==='
# MOC module internally uses Invoke-Command which may throw non-fatal WinRM errors
# on single-node setups. Temporarily allow errors so config generation completes.
$ErrorActionPreference = 'Continue'
New-ArcHciAksConfigFiles `
    -subscriptionID   '{cfg["subscription"]}' `
    -location         '{cfg["location"]}' `
    -resourceGroup    '{cfg["rg"]}' `
    -resourceName     '{cfg["appliance"]}' `
    -workDirectory    $workDir `
    -vnetName         'appliance-vnet' `
    -vSwitchName      'ExternalSwitch' `
    -gateway          '10.0.0.1' `
    -dnsservers       '8.8.8.8' `
    -ipaddressprefix  '10.0.0.0/24' `
    -k8snodeippoolstart '10.0.0.10' `
    -k8snodeippoolend   '10.0.0.30' `
    -vippoolstart     '10.0.0.31' `
    -vippoolend       '10.0.0.50' `
    -controlPlaneIP   '10.0.0.60' `
    -cloudFqdn        $cloudFqdn
$ErrorActionPreference = 'Stop'

Write-Host "Config file: $workDir\\hci-appliance.yaml"
if (Test-Path "$workDir\\hci-appliance.yaml") {{
    Write-Host 'DONE: Config files generated.'
}} else {{
    throw 'Config file not found after generation.'
}}
"""


def script_prepare_appliance(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {{ throw 'az login failed' }}
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {{ throw 'az account set failed' }}

$configFile = '{cfg["work_dir"]}\\hci-appliance.yaml'

Write-Host '=== Preparing Arc appliance ==='
az arcappliance prepare hci --config-file $configFile 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'az arcappliance prepare failed' }}

Write-Host 'DONE: Appliance prepared.'
"""


def script_deploy_appliance(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {{ throw 'az login failed' }}
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {{ throw 'az account set failed' }}

$configFile = '{cfg["work_dir"]}\\hci-appliance.yaml'

Write-Host '=== Deploying Arc appliance VM (this takes 15-25 min) ==='
az arcappliance deploy hci --config-file $configFile --outfile '{cfg["work_dir"]}\\kubeconfig' 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'az arcappliance deploy failed' }}

Write-Host 'DONE: Appliance VM deployed.'
"""


def script_create_appliance_resource(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {{ throw 'az login failed' }}
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {{ throw 'az account set failed' }}

$configFile = '{cfg["work_dir"]}\\hci-appliance.yaml'
$kubeconfig = '{cfg["work_dir"]}\\kubeconfig'

Write-Host '=== Creating Arc appliance ARM resource ==='
az arcappliance create hci --config-file $configFile --kubeconfig $kubeconfig 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'az arcappliance create failed' }}

# Wait for Running state
Write-Host 'Waiting for appliance to reach Running state...'
$maxWait = 300; $elapsed = 0
do {{
    Start-Sleep -Seconds 15; $elapsed += 15
    $state = az arcappliance show -g '{cfg["rg"]}' -n '{cfg["appliance"]}' --query status -o tsv 2>$null
    Write-Host "  Status: $state ($($elapsed)s)"
}} while ($state -ne 'Running' -and $elapsed -lt $maxWait)

if ($state -ne 'Running') {{ throw "Appliance not Running after $maxWait`s (state=$state)" }}
Write-Host 'DONE: Appliance resource created and running.'
"""


def script_install_aks_extension(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null

$workDir = '{cfg["work_dir"]}'
ipmo ((Get-Module 'ArcHci' -ListAvailable | Sort-Object Version -Desc)[0].ModuleBase + '\\ArcHci.psm1')

$aksExtCfg = Join-Path $workDir 'aks-extension-config.json'
Add-ExtensionConfigToFile -configFilePath $aksExtCfg -key 'Microsoft.CustomLocation.ServiceAccount' -value 'default'

Write-Host '=== Installing AKS Arc extension ==='
az k8s-extension create -g '{cfg["rg"]}' -c '{cfg["appliance"]}' --cluster-type appliances `
    --name hybridaksextension --extension-type Microsoft.HybridAKSOperator `
    --config-file $aksExtCfg --release-train stable --auto-upgrade-minor-version true 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'AKS extension install failed' }}

Write-Host 'DONE: AKS Arc extension installed.'
"""


def script_install_vmss_extension(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null

$workDir = '{cfg["work_dir"]}'
Import-Module ArcHci -WarningAction SilentlyContinue

$vmExtCfg = Join-Path $workDir 'vm-extension-config.json'
Add-ExtensionConfigToFile -configFilePath $vmExtCfg -key 'Microsoft.CustomLocation.ServiceAccount' -value 'default'
Add-ExtensionConfigToFile -configFilePath $vmExtCfg -key 'infraCheck' -value 'false'

New-ArcHciIdentityFiles -workDirectory $workDir
$mocCfg = Join-Path $workDir 'hci-config.json'

Write-Host '=== Installing VMSS HCI extension ==='
az k8s-extension create -g '{cfg["rg"]}' -c '{cfg["appliance"]}' --cluster-type appliances `
    --name vmss-hci --extension-type Microsoft.AZStackHCI.Operator --scope cluster `
    --release-namespace helm-operator2 `
    --config-protected-file $mocCfg --config-file $vmExtCfg `
    --release-train stable --auto-upgrade-minor-version true 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'VMSS extension install failed' }}

Write-Host 'DONE: VMSS HCI extension installed.'
"""


def script_create_custom_location(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null

$appId  = az arcappliance show -g '{cfg["rg"]}' -n '{cfg["appliance"]}' --query id -o tsv
$aksExt = az k8s-extension show -g '{cfg["rg"]}' -c '{cfg["appliance"]}' --cluster-type appliances --name hybridaksextension --query id -o tsv
$vmExt  = az k8s-extension show -g '{cfg["rg"]}' -c '{cfg["appliance"]}' --cluster-type appliances --name vmss-hci --query id -o tsv

Write-Host '=== Creating custom location ==='
az customlocation create -g '{cfg["rg"]}' -n '{cfg["custom_location"]}' `
    --namespace default --host-resource-id $appId `
    --cluster-extension-ids $aksExt $vmExt 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'Custom location creation failed' }}

$clId = az customlocation show -n '{cfg["custom_location"]}' -g '{cfg["rg"]}' --query id -o tsv
Write-Host "DONE: Custom location created. ID: $clId"
"""


def script_deploy_lnet(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null

$clId = az customlocation show -n '{cfg["custom_location"]}' -g '{cfg["rg"]}' --query id -o tsv

Write-Host '=== Creating logical network ==='
az stack-hci-vm network lnet create `
    --subscription '{cfg["subscription"]}' -g '{cfg["rg"]}' `
    --custom-location $clId --location '{cfg["location"]}' `
    --name '{cfg["lnet"]}' --ip-allocation-method Static `
    --address-prefix '10.0.0.0/24' --dns-servers '8.8.8.8' `
    --gateway '10.0.0.1' --vlan 0 `
    --ip-pool-start '10.0.0.10' --ip-pool-end '10.0.0.30' `
    --vm-switch-name 'ExternalSwitch' 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'Logical network creation failed' }}

Write-Host 'DONE: Logical network created.'
"""


def script_deploy_aks(cfg):
    return f"""\
$ErrorActionPreference = 'Stop'
{PS_PREAMBLE}
Write-Host '=== Logging into Azure ==='
az login --identity 2>&1 | Out-Null
az account set -s '{cfg["subscription"]}' 2>&1 | Out-Null

$clId   = az customlocation show -n '{cfg["custom_location"]}' -g '{cfg["rg"]}' --query id -o tsv
$lnetId = az stack-hci-vm network lnet show -n '{cfg["lnet"]}' -g '{cfg["rg"]}' --query id -o tsv

Write-Host '=== Creating AKS Arc cluster ==='
az aksarc create --name '{cfg["aks_cluster"]}' -g '{cfg["rg"]}' `
    --custom-location $clId --vnet-ids $lnetId --generate-ssh-keys 2>&1
if ($LASTEXITCODE -ne 0) {{ throw 'AKS Arc cluster creation failed' }}

Write-Host 'DONE: AKS Arc cluster deployed.'
"""


# ──────────────────────────────────────────────────────────────────────
# Main orchestrator
# ──────────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(
        description="AKS Arc Jumpstart — Phase 2 Deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Example:\n  python deploy_phase2.py --rg jumpstart-mn-rg15 "
               "--location eastus2 --subscription <id> --password 'JumpStart@2026!'",
    )
    p.add_argument("--rg", required=True, help="Resource group")
    p.add_argument("--vm", default="jumpstartVM-1", help="VM name (default: jumpstartVM-1)")
    p.add_argument("--location", required=True)
    p.add_argument("--subscription", required=True)
    p.add_argument("--user", default="aksadmin", help="VM admin user (default: aksadmin)")
    p.add_argument("--password", required=True, help="VM admin password")
    p.add_argument("--start-from", type=int, default=1, help="Resume from step N")
    p.add_argument("--arc-hci-version", default="1.3.15")
    p.add_argument("--appliance", default=None, help="Appliance name")
    args = p.parse_args()

    # Derive resource names
    appliance = args.appliance or f"{args.vm}-appliance"
    custom_loc = f"{appliance}-cl"
    lnet = f"{appliance}-lnet"
    aks_cluster = f"{appliance}-aksarc"

    # Detect workDirectory from the VM
    print("Detecting VM workDirectory…")
    wd_result = az(
        "vm", "run-command", "invoke",
        "--resource-group", args.rg, "--name", args.vm,
        "--command-id", "RunPowerShellScript",
        "--scripts", "[Environment]::GetEnvironmentVariable('WorkingDir','Machine')",
    )
    work_dir = ""
    if wd_result and isinstance(wd_result, dict):
        vals = wd_result.get("value", [])
        if vals:
            work_dir = vals[0].get("message", "").strip()
    if not work_dir:
        work_dir = "C:\\ArcHCI"
    print(f"  workDirectory: {work_dir}")

    cfg = {
        "rg": args.rg,
        "location": args.location,
        "subscription": args.subscription,
        "appliance": appliance,
        "custom_location": custom_loc,
        "lnet": lnet,
        "aks_cluster": aks_cluster,
        "work_dir": work_dir,
    }

    runner = VMRunner(args.rg, args.vm, args.user, args.password)

    # Define steps: (name, script_fn, timeout_seconds)
    steps = [
        ("install-modules",     script_install_modules(args.arc_hci_version),  900),
        ("generate-config",     script_generate_config(cfg),                   600),
        ("prepare-appliance",   script_prepare_appliance(cfg),                1800),
        ("deploy-appliance",    script_deploy_appliance(cfg),                 3600),
        ("create-appliance",    script_create_appliance_resource(cfg),         900),
        ("install-aks-ext",     script_install_aks_extension(cfg),             900),
        ("install-vmss-ext",    script_install_vmss_extension(cfg),            900),
        ("create-custom-loc",   script_create_custom_location(cfg),            600),
        ("deploy-lnet",         script_deploy_lnet(cfg),                       600),
        ("deploy-aks-cluster",  script_deploy_aks(cfg),                       3600),
    ]

    total = len(steps)
    print(f"\n{'═' * 60}")
    print(f"  AKS Arc Phase 2 — {total} steps")
    print(f"  RG: {args.rg} | VM: {args.vm} | Location: {args.location}")
    print(f"  Appliance: {appliance}")
    print(f"{'═' * 60}\n")

    for i, (name, script, timeout) in enumerate(steps, 1):
        if i < args.start_from:
            print(f"[{i}/{total}] {name} — skipped (--start-from {args.start_from})")
            continue

        print(f"\n{'─' * 60}")
        print(f"[{i}/{total}] {name}")
        print(f"{'─' * 60}")

        try:
            output = runner.execute(name, script, timeout)
            # Show summary (last few lines)
            if output:
                lines = output.strip().splitlines()
                for line in lines[-5:]:
                    print(f"  │ {line}")
            print(f"  ✓ {name} succeeded")
        except Exception as e:
            print(f"\n  ✗ {name} FAILED: {e}")
            print(f"\n  Resume with: --start-from {i}")
            sys.exit(1)

    print(f"\n{'═' * 60}")
    print(f"  ✓ All {total} steps completed!")
    print(f"  AKS Arc cluster: {aks_cluster}")
    print(f"{'═' * 60}")


if __name__ == "__main__":
    main()
