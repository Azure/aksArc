$baseModulePath = "C:\Program Files\WindowsPowerShell\Modules"

function CleanupModule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [String]$Name
    )


    Uninstall-Module $Name -Force -ErrorAction SilentlyContinue -AllVersions -Verbose

    # Still try to look at the path
    $modulePath = Join-Path $baseModulePath $Name
    if (Test-Path $modulePath) 
    {
        Remove-Item $modulePath -Force -Recurse -Verbose
        Write-Verbose "Deleted File $modulePath"
    }

}
$VerbosePreference = "Continue"

$modules = @('AksHci', 'Moc', 'Kva', 'DownloadSDK', 'TraceProvider')
$DependentModules = @('Az.Accounts', 'Az.Resources', 'AzureAD')

# write output of current status of installed modules
$modules | ForEach-Object { Get-Module -Name $_ -ListAvailable | Format-Table -Property Name, Version, Path }
$DependentModules | ForEach-Object { Get-Module -Name $_ -ListAvailable | Format-Table -Property Name, Version, Path }

# cleanup akshci modules
$modules | ForEach-Object { CleanupModule -Name $_ -ErrorAction SilentlyContinue }

# cleanup dependent modules
$DependentModules | ForEach-Object { CleanupModule -Name $_ -ErrorAction SilentlyContinue }

