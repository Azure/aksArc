$modules = @("AksHci", "Kva", "Moc", "DownloadSdk", "TraceProvider")
foreach($module in $modules)
{
    $current = Get-InstalledModule -Name $module -ErrorAction Ignore
    if (-not $current)
    {
        Write-Host $("[Module: $module] Is not installed, skipping")
        continue
    }
    Write-Host $("[Module: $module] Newest installed version is $($current.Version)")
    $versions = Get-InstalledModule -Name $module -AllVersions
    foreach($version in $versions)
    {
        if ($version.Version -eq $current.Version)
        {
            Write-Host $("[Module: $module] Skipping uninstall for version $($version.Version)")
            continue
        }
        Write-Host $("[Module: $module] Uninstalling version $($version.Version)")
        $version | Uninstall-Module -Force -Confirm:$false
    }
}
