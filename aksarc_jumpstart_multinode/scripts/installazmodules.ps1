param(
    [string]$arcHciVersion = "1.3.15",
    [string]$adminUsername = "aksadmin",
    [string]$adminPassword = ""
)

Start-Transcript -Path "$env:LogDirectory\installazmodules.ps1.log" -Append

$VerbosePreference = "Continue"
Write-Host "Installing ArcHci module v$arcHciVersion..."
Install-Module -Name ArcHci -Repository PSGallery -Force -Confirm:$false -RequiredVersion $arcHciVersion

Write-Host "Registering Azure resource providers..."
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az provider register --namespace Microsoft.ResourceConnector --wait
az provider register --namespace Microsoft.HybridConnectivity --wait
az provider register --namespace Microsoft.HybridContainerService --wait

Write-Host "Installing Azure CLI extensions (SYSTEM context)..."
az extension add --name k8s-extension --upgrade --yes
az extension add --name customlocation --upgrade --yes
az extension add --name aksarc --upgrade --yes
az extension add --name connectedk8s --upgrade --yes
az extension add --name arcappliance --upgrade --yes
az extension add --name stack-hci-vm --upgrade --yes

# Also install under admin user context (scheduled tasks run as admin user)
if (-not [string]::IsNullOrEmpty($adminPassword)) {
    Write-Host "Installing Azure CLI extensions for $adminUsername..."
    $setupDir = 'C:\ClusterSetup'
    New-Item -Path $setupDir -ItemType Directory -Force | Out-Null

    $extScript = @"
az extension add --name k8s-extension --upgrade --yes
az extension add --name customlocation --upgrade --yes
az extension add --name aksarc --upgrade --yes
az extension add --name connectedk8s --upgrade --yes
az extension add --name arcappliance --upgrade --yes
az extension add --name stack-hci-vm --upgrade --yes
'DONE' | Out-File '$setupDir\ext-result.txt' -Force
"@
    $extScript | Out-File "$setupDir\install-ext.ps1" -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Unrestricted -File $setupDir\install-ext.ps1"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(3)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
    Register-ScheduledTask -TaskName 'InstallExtensions' -Action $action -Trigger $trigger -Settings $settings -User $adminUsername -Password $adminPassword -RunLevel Highest -Force
    Start-ScheduledTask -TaskName 'InstallExtensions'

    $maxWait = 600
    $elapsed = 0
    do {
        Start-Sleep -Seconds 30
        $elapsed += 30
        $taskState = (Get-ScheduledTask -TaskName 'InstallExtensions').State
        Write-Host "  [$elapsed`s] Extension install: $taskState"
    } while ($taskState -eq 'Running' -and $elapsed -lt $maxWait)

    Unregister-ScheduledTask -TaskName 'InstallExtensions' -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Azure CLI extensions installed for $adminUsername."
}

Stop-Transcript
