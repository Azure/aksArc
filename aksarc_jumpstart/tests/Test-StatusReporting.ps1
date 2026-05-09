# Test harness for status-reporting.ps1.
#
# Mocks the `az` command so each scenario can be exercised without a live
# Azure subscription. Run with:
#   pwsh -NoProfile -File ./tests/Test-StatusReporting.ps1
# or
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-StatusReporting.ps1

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpersPath = Join-Path (Split-Path -Parent $here) 'status-reporting.ps1'

# Each test runs in a fresh PowerShell instance to get a clean script-scoped
# state and a clean `az` function definition. This also means `exit N` from
# Invoke-StepFailure terminates only the child, not the test harness.
function Invoke-Scenario {
  param(
    [Parameter(Mandatory = $true)] [string] $Name,
    [Parameter(Mandatory = $true)] [string] $AzMockBody,
    [Parameter(Mandatory = $true)] [int]    $ExpectedExitCode,
    [Parameter()]                  [string] $ExpectedOutputContains
  )

  $script = @"
`$ErrorActionPreference = 'Stop'
function az {
$AzMockBody
}
. '$helpersPath'
Initialize-ExecutionStatus -ScriptName 'test'
Invoke-VmScriptDeployment ``
  -StepName 'TestStep' ``
  -ResourceGroup 'rg' ``
  -Location 'eastus' ``
  -VmName 'vm' ``
  -ScriptFileUri 'https://example/script.ps1' ``
  -InnerScript 'script.ps1'
# Reached only on success path.
`$script:ExecutionStatus.Status = 'Success'
Write-ExecutionStatus
"@

  $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.ps1')
  try {
    Set-Content -Path $tmp -Value $script -Encoding UTF8
    $output = & pwsh -NoProfile -File $tmp 2>&1 | Out-String
    $exit = $LASTEXITCODE
  }
  finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }

  $passed = $true
  $reasons = @()
  if ($exit -ne $ExpectedExitCode) {
    $passed = $false
    $reasons += "exit code expected=$ExpectedExitCode actual=$exit"
  }
  if ($ExpectedOutputContains -and ($output -notmatch [regex]::Escape($ExpectedOutputContains))) {
    $passed = $false
    $reasons += "output missing expected substring '$ExpectedOutputContains'"
  }

  if ($passed) {
    Write-Host "PASS  $Name"
  }
  else {
    Write-Host "FAIL  $Name"
    foreach ($r in $reasons) { Write-Host "      $r" }
    Write-Host "      ---- output ----"
    foreach ($line in ($output -split "`r?`n")) { Write-Host "      $line" }
    $script:FailCount++
  }
}

$script:FailCount = 0

# --- Scenario 1: deployment success + extension success + clean stderr ----
$mock1 = @'
  if ($args -contains 'deployment' -and $args -contains 'create') {
    $global:LASTEXITCODE = 0
    return '{}'
  }
  if ($args -contains 'extension' -and $args -contains 'show') {
    $global:LASTEXITCODE = 0
    return '{"statuses":[{"code":"ProvisioningState/succeeded","level":"Info","message":"Enable succeeded"}],"substatuses":[{"code":"ComponentStatus/StdOut/succeeded","message":"all good"},{"code":"ComponentStatus/StdErr/succeeded","message":""}]}'
  }
  $global:LASTEXITCODE = 0
'@
Invoke-Scenario -Name 'success: deploy ok + extension succeeded + empty stderr' `
                -AzMockBody $mock1 -ExpectedExitCode 0 -ExpectedOutputContains 'Status: Success'

# --- Scenario 2: deployment success + extension failed (silent failure!) ----
# This is the bug we are fixing: `az deployment group create` returned 0 but
# the script inside the VM actually failed.
$mock2 = @'
  if ($args -contains 'deployment' -and $args -contains 'create') {
    $global:LASTEXITCODE = 0
    return '{}'
  }
  if ($args -contains 'extension' -and $args -contains 'show') {
    $global:LASTEXITCODE = 0
    return '{"statuses":[{"code":"ProvisioningState/failed","level":"Error","message":"Enable failed: VM script returned non-zero"}],"substatuses":[{"code":"ComponentStatus/StdOut/failed","message":"some progress output"},{"code":"ComponentStatus/StdErr/failed","message":"INNER_SCRIPT_ERROR: Install-Module failed"}]}'
  }
  $global:LASTEXITCODE = 0
'@
Invoke-Scenario -Name 'silent-failure: deploy ok + extension Failed -> caught' `
                -AzMockBody $mock2 -ExpectedExitCode 1 `
                -ExpectedOutputContains 'INNER_SCRIPT_ERROR: Install-Module failed'

# --- Scenario 3: deployment failed (loud failure) ----
$mock3 = @'
  if ($args -contains 'deployment' -and $args -contains 'create') {
    $global:LASTEXITCODE = 2
    Write-Error 'simulated deployment error' -ErrorAction Continue
    return ''
  }
  if ($args -contains 'extension' -and $args -contains 'show') {
    $global:LASTEXITCODE = 0
    return '{"statuses":[{"code":"ProvisioningState/failed","level":"Error","message":"timeout"}],"substatuses":[{"code":"ComponentStatus/StdErr/failed","message":"timed out waiting for VM"}]}'
  }
  $global:LASTEXITCODE = 0
'@
Invoke-Scenario -Name 'deploy-failure: deploy non-zero -> caught with extension detail' `
                -AzMockBody $mock3 -ExpectedExitCode 2 `
                -ExpectedOutputContains 'timed out waiting for VM'

# --- Scenario 4: deployment success + extension success + non-empty stderr (warn) ----
$mock4 = @'
  if ($args -contains 'deployment' -and $args -contains 'create') {
    $global:LASTEXITCODE = 0
    return '{}'
  }
  if ($args -contains 'extension' -and $args -contains 'show') {
    $global:LASTEXITCODE = 0
    return '{"statuses":[{"code":"ProvisioningState/succeeded","level":"Info","message":"Enable succeeded"}],"substatuses":[{"code":"ComponentStatus/StdOut/succeeded","message":"ok"},{"code":"ComponentStatus/StdErr/succeeded","message":"WARNING: deprecated cmdlet"}]}'
  }
  $global:LASTEXITCODE = 0
'@
Invoke-Scenario -Name 'noisy-success: succeeded + non-empty stderr -> warn but pass' `
                -AzMockBody $mock4 -ExpectedExitCode 0 `
                -ExpectedOutputContains 'WARNING: deprecated cmdlet'

# --- Scenario 5: extension show itself fails (network/auth issue) ----
# Should NOT mask a successful deployment -- if deploy returned 0 and we cannot
# fetch the instance view, treat as success (log nothing; don't crash).
$mock5 = @'
  if ($args -contains 'deployment' -and $args -contains 'create') {
    $global:LASTEXITCODE = 0
    return '{}'
  }
  if ($args -contains 'extension' -and $args -contains 'show') {
    $global:LASTEXITCODE = 1
    return ''
  }
  $global:LASTEXITCODE = 0
'@
Invoke-Scenario -Name 'extension-show-fails: deploy ok + view unfetchable -> pass' `
                -AzMockBody $mock5 -ExpectedExitCode 0 `
                -ExpectedOutputContains 'Status: Success'

if ($script:FailCount -gt 0) {
  Write-Host "`n$script:FailCount scenario(s) failed."
  exit 1
}

Write-Host "`nAll scenarios passed."
exit 0
