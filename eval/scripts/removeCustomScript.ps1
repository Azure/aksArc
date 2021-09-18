[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $vmName,
    [Parameter(Mandatory = $true)]
    [string] $subscriptionId,
    [Parameter(Mandatory = $true)]
    [string] $tenantId,
    [Parameter(Mandatory = $true)]
    [string] $appId,
    [Parameter(Mandatory = $true)]
    [string] $appSecret
)

$ErrorActionPreference = 'Stop'
function DecodeParam($parameter) {
    if ($parameter.StartsWith("base64:")) {
        $encodedParameter = $parameter.Split(':', 2)[1]
        $decodedArray = [System.Convert]::FromBase64String($encodedParameter);
        $parameter = [System.Text.Encoding]::UTF8.GetString($decodedArray); 
    }
    return $parameter
}

$appSecret = DecodeParam $appSecret
$strAppSecret = ConvertTo-SecureString $appSecret -Force -AsPlainText -Verbose
$spCreds = New-Object System.Management.Automation.PSCredential ($appId, $strAppSecret)
Connect-AzAccount -Credential $spCreds -ServicePrincipal -Tenant $tenantId -Subscription $subscriptionId
Remove-AzVMCustomScriptExtension -Name 'InstallWindowsAdminCenter' -ResourceGroupName $resourceGroupName -VMName $vmName -Force