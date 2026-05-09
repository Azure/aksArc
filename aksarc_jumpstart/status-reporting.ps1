# Shared status reporting and ARM-deployment error surfacing helpers.
#
# Dot-source from a calling script:
#     . "$PSScriptRoot/status-reporting.ps1"
#     Initialize-ExecutionStatus -ScriptName 'jumpstart.ps1'
#
# After Initialize-ExecutionStatus, the caller has access to:
#     Write-ExecutionStatus
#     Invoke-StepFailure        -StepName ... -ErrorText ...
#     Invoke-VmScriptDeployment -StepName ... -ResourceGroup ... -VmName ...
#                               -ScriptFileUri ... -InnerScript ...
#
# These helpers update a script-scoped $script:ExecutionStatus hashtable.

function Initialize-ExecutionStatus {
  param(
    [Parameter(Mandatory = $true)] [string] $ScriptName
  )
  $script:ExecutionStatus = @{
    Status         = "InProgress"
    Script         = $ScriptName
    StartTime      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CompletedSteps = @()
    FailedStep     = $null
    ErrorMessage   = ""
    ExitCode       = 0
  }
}

function Write-ExecutionStatus {
  $script:ExecutionStatus.EndTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Write-Host "`n===== EXECUTION STATUS ====="
  Write-Host "Status: $($script:ExecutionStatus.Status)"
  if ($script:ExecutionStatus.Status -eq "Failure") {
    Write-Host "Failed Step: $($script:ExecutionStatus.FailedStep)"
    Write-Host "Error Message: $($script:ExecutionStatus.ErrorMessage)"
  }
  Write-Host "Exit Code: $($script:ExecutionStatus.ExitCode)"
  Write-Host "Completed Steps: $($script:ExecutionStatus.CompletedSteps -join ', ')"
  Write-Host "Start Time: $($script:ExecutionStatus.StartTime)"
  Write-Host "End Time: $($script:ExecutionStatus.EndTime)"
  Write-Host "============================"
}

function Invoke-StepFailure {
  param(
    [Parameter(Mandatory = $true)] [string] $StepName,
    [Parameter(Mandatory = $true)] [string] $ErrorText,
    [Parameter()] [int] $ExitCode = 1
  )
  $script:ExecutionStatus.Status       = "Failure"
  $script:ExecutionStatus.FailedStep   = $StepName
  $script:ExecutionStatus.ErrorMessage = $ErrorText
  $script:ExecutionStatus.ExitCode     = $ExitCode
  Write-ExecutionStatus
  exit $ExitCode
}

function Add-CompletedStep {
  param([Parameter(Mandatory = $true)] [string] $StepName)
  $script:ExecutionStatus.CompletedSteps += $StepName
}

# Deploy executescript-template.json and treat ANY of these as failure:
#   1. az deployment group create returned non-zero
#   2. Extension instance view shows ProvisioningState != succeeded
#   3. (Soft) Extension StdErr substatus is non-empty -> warn but don't fail
#
# On failure, surfaces ProvisioningState message + StdOut + StdErr in the
# error text instead of just "az command failed with exit code N".
#
# `commandToExecute` is constructed identically to the pre-existing code path
# (`powershell.exe -ExecutionPolicy Unrestricted -File <innerScript>`) so this
# change does not alter what runs inside the VM -- it only adds a post-deploy
# inspection of the extension to catch failures the deployment exit code
# missed (the actual bug we are fixing).
function Invoke-VmScriptDeployment {
  param(
    [Parameter(Mandatory = $true)] [string] $StepName,
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $Location,
    [Parameter(Mandatory = $true)] [string] $VmName,
    [Parameter(Mandatory = $true)] [string] $ScriptFileUri,
    [Parameter(Mandatory = $true)] [string] $InnerScript,
    [Parameter()] [string] $TemplateFile = "./configuration/executescript-template.json",
    [Parameter()] [string] $DeploymentName
  )

  if ([string]::IsNullOrEmpty($DeploymentName)) {
    $base = ($InnerScript -split ' ')[0]
    $DeploymentName = "executescript-$VmName-$($base -replace '\.ps1$','')"
  }

  $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File $InnerScript"
  Write-Host "Executing $commandToExecute from $ScriptFileUri on VM $VmName ..."

  az deployment group create `
    --name $DeploymentName `
    --resource-group $ResourceGroup `
    --template-file $TemplateFile `
    --parameters location=$Location vmName=$VmName scriptFileUri=$ScriptFileUri commandToExecute=$commandToExecute
  $deploymentExitCode = $LASTEXITCODE

  # Always inspect the extension instance view for ground truth.
  $instanceViewJson = az vm extension show `
    --resource-group $ResourceGroup `
    --vm-name $VmName `
    --name CustomScriptExtension `
    --instance-view `
    --query instanceView `
    -o json 2>$null
  $extLookupExitCode = $LASTEXITCODE

  $provisioningState = $null
  $statusMessage = ""
  $stdOut = ""
  $stdErr = ""
  if ($extLookupExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($instanceViewJson)) {
    try {
      $iv = $instanceViewJson | ConvertFrom-Json -ErrorAction Stop
      $provStatus = $iv.statuses | Where-Object { $_.code -like 'ProvisioningState/*' } | Select-Object -First 1
      if ($provStatus) {
        $provisioningState = $provStatus.code
        $statusMessage = $provStatus.message
      }
      $stdOutSub = $iv.substatuses | Where-Object { $_.code -like 'ComponentStatus/StdOut/*' } | Select-Object -First 1
      if ($stdOutSub) { $stdOut = $stdOutSub.message }
      $stdErrSub = $iv.substatuses | Where-Object { $_.code -like 'ComponentStatus/StdErr/*' } | Select-Object -First 1
      if ($stdErrSub) { $stdErr = $stdErrSub.message }
    }
    catch {
      Write-Host "WARNING: could not parse extension instance view: $_"
    }
  }

  $extensionFailed = ($null -ne $provisioningState) -and ($provisioningState -notlike '*succeeded')
  $hasStdErr = -not [string]::IsNullOrWhiteSpace($stdErr)

  if ($deploymentExitCode -ne 0 -or $extensionFailed) {
    $failExitCode = if ($deploymentExitCode -ne 0) { $deploymentExitCode } else { 1 }
    $errorText = "Failed to execute script '$InnerScript' on VM '$VmName' (step '$StepName'). " +
                 "DeploymentExitCode=$deploymentExitCode; ProvisioningState=$provisioningState; " +
                 "StatusMessage=$statusMessage; StdErr=$stdErr; StdOut=$stdOut"
    Invoke-StepFailure -StepName $StepName -ExitCode $failExitCode -ErrorText $errorText
  }

  if ($hasStdErr) {
    Write-Host "WARNING: step '$StepName' completed but extension StdErr was non-empty:"
    Write-Host $stdErr
  }

  Add-CompletedStep -StepName $StepName
}
