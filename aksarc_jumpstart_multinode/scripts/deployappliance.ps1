param(
    [string]$resource_group = "jumpstart-rg",
    [string]$appliance_name = "jumpstart-appliance",
    [string]$workDirectory,
    [string]$location = "eastus",
    [string]$subscription,
    [string]$adminUsername = "aksadmin",
    [string]$adminPassword = ""
)

if ([string]::IsNullOrEmpty($workDirectory)) {
    $workDirectory = "$env:WorkingDir"
}

Start-Transcript -Path "$env:LogDirectory\deployappliance.ps1.log" -Append

try {
    # Runs via CustomScriptExtension (SYSTEM context).
    # New-ArcHciAksConfigFiles needs WinRM to local node → scheduled task as admin user.

    $setupDir = 'C:\ClusterSetup'
    New-Item -Path $setupDir -ItemType Directory -Force | Out-Null

    $scriptContent = @"
`$ErrorActionPreference = 'Continue'
Start-Transcript -Path '$setupDir\deployappliance-inner.log' -Force
try {
    `$VerbosePreference = 'Continue'
    md '$workDirectory' -ErrorAction SilentlyContinue

    # Determine MOC cloud agent endpoint — cluster IP if cluster exists, else node IP
    `$cluster = Get-Cluster -ErrorAction SilentlyContinue
    if (`$cluster) {
        `$cloudFqdn = '10.0.0.100'
    } else {
        `$cloudFqdn = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.IPAddress -like '10.0.0.*' -and `$_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
    }
    Write-Host "Using cloudFqdn: `$cloudFqdn"

    Write-Host 'Creating Arc HCI AKS configuration files...'
    Import-Module ArcHci -WarningAction SilentlyContinue
    New-ArcHciAksConfigFiles -subscriptionID '$subscription' -location '$location' -resourceGroup '$resource_group' ``
        -resourceName '$appliance_name' -workDirectory '$workDirectory' -vnetName 'appliance-vnet' ``
        -vSwitchName 'ExternalSwitch' -gateway '10.0.0.1' -dnsservers '8.8.8.8' -ipaddressprefix '10.0.0.0/24' ``
        -k8snodeippoolstart '10.0.0.10' -k8snodeippoolend '10.0.0.30' ``
        -vippoolstart '10.0.0.31' -vippoolend '10.0.0.50' ``
        -controlPlaneIP '10.0.0.60' -cloudFqdn `$cloudFqdn

    `$configFilePath = '$workDirectory\hci-appliance.yaml'

    Write-Host 'Logging into Azure with managed identity...'
    az login --identity 2>&1
    if (`$LASTEXITCODE -ne 0) { throw 'Failed to login to Azure.' }

    az account set -s '$subscription' 2>&1
    if (`$LASTEXITCODE -ne 0) { throw 'Failed to set subscription.' }

    Write-Host 'Preparing Arc appliance...'
    az arcappliance prepare hci --config-file `$configFilePath 2>&1
    if (`$LASTEXITCODE -ne 0) { throw 'Failed to prepare Arc appliance.' }

    Write-Host 'Deploying Arc appliance...'
    az arcappliance deploy hci --config-file `$configFilePath --outfile '$workDirectory\kubeconfig' 2>&1
    if (`$LASTEXITCODE -ne 0) { throw 'Failed to deploy Arc appliance.' }

    Write-Host 'Creating Arc appliance...'
    az arcappliance create hci --config-file `$configFilePath --kubeconfig '$workDirectory\kubeconfig' 2>&1
    if (`$LASTEXITCODE -ne 0) { throw 'Failed to create Arc appliance.' }

    Write-Host 'Arc appliance deployment completed.'
    'SUCCESS' | Out-File '$setupDir\appliance-result.txt' -Force
} catch {
    Write-Host "ERROR: `$_"
    'FAILED' | Out-File '$setupDir\appliance-result.txt' -Force
    throw
}
Stop-Transcript
"@

    $scriptFilePath = "$setupDir\deployappliance-inner.ps1"
    $scriptContent | Out-File -FilePath $scriptFilePath -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Unrestricted -File $scriptFilePath"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 3)
    Register-ScheduledTask -TaskName 'DeployAppliance' -Action $action -Trigger $trigger -Settings $settings -User $adminUsername -Password $adminPassword -RunLevel Highest -Force
    Start-ScheduledTask -TaskName 'DeployAppliance'

    Write-Host "Appliance deployment started as $adminUsername. Monitoring..."
    $maxWait = 7200
    $elapsed = 0
    do {
        Start-Sleep -Seconds 120
        $elapsed += 120
        $taskState = (Get-ScheduledTask -TaskName 'DeployAppliance').State
        if (Test-Path "$setupDir\deployappliance-inner.log") {
            $lastLine = Get-Content "$setupDir\deployappliance-inner.log" -Tail 1 -ErrorAction SilentlyContinue
            Write-Host "  [$([math]::Round($elapsed/60))min] $taskState | $lastLine"
        } else {
            Write-Host "  [$([math]::Round($elapsed/60))min] $taskState"
        }
    } while ($taskState -eq 'Running' -and $elapsed -lt $maxWait)

    if (Test-Path "$setupDir\appliance-result.txt") {
        $result = Get-Content "$setupDir\appliance-result.txt"
        if ($result -ne 'SUCCESS') {
            if (Test-Path "$setupDir\deployappliance-inner.log") {
                Get-Content "$setupDir\deployappliance-inner.log" | Select-Object -Last 30
            }
            throw "Arc appliance deployment failed."
        }
    } else {
        throw "Arc appliance deployment timed out."
    }

    Unregister-ScheduledTask -TaskName 'DeployAppliance' -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Arc appliance deployment completed successfully."
}
catch {
    Write-Error "Arc appliance deployment failed: $_"
    Unregister-ScheduledTask -TaskName 'DeployAppliance' -Confirm:$false -ErrorAction SilentlyContinue
    throw
}
finally {
    Stop-Transcript
}
