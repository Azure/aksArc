configuration AKSHCIHost
{
    Import-DscResource -ModuleName PackageManagement -ModuleVersion 1.4.7
    #Import-DscResource -ModuleName PowerShellGet -ModuleVersion 2.2.5
    Import-DscResource -ModuleName PowerShellGet -ModuleVersion 3.0.11

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
        }
        
        # PackageManagement Module 1.4.7

        <#
        PackageManagementSource PSGallery {
            Ensure             = "Present"
            Name               = "PSGallery"
            ProviderName       = "PowerShellGet"
            SourceLocation     = "https://www.powershellgallery.com/api/v2"
            InstallationPolicy = "Trusted"
        }
        
        PackageManagement PSModule {
            Ensure    = "Present"
            Name      = "AksHci"
            Source    = "PSGallery"
            DependsOn = "[PSRepository]PSGallery"
        }
        #>

        # Trust the PSGallery Repo 2.2.5 then 3.0.11
        
        <#
        PSRepository PSGallery {
            Ensure = "Present"
            Name = "PSGallery"
            SourceLocation = "https://www.powershellgallery.com/api/v2"
            InstallationPolicy = "Trusted"
        }
        #>
        
        PSRepository PSGallery {
            Ensure             = "Present"
            Name               = "PSGallery"
            URL                = "https://www.powershellgallery.com/api/v2"
            InstallationPolicy = "Trusted"
        }

        # Add the module 2.2.5 then 3.0.11

        <#
        PSModule GetAksHciModule {
            Ensure = "Present"
            Name = "AksHci"
            Repository = "PSGallery"
            InstallationPolicy = "Trusted"
            Force = $true
            AllowClobber = $true
            DependsOn = "[PSRepository]PSGallery"
        }
        #>

        PSModule GetAksHciModule {
            Ensure             = "Present"
            Name               = "AksHci"
            Repository         = "PSGallery"
            InstallationPolicy = "Trusted"
            NoClobber          = $false
            AcceptLicense      = $true
            DependsOn          = "[PSRepository]PSGallery"
        }
    }
}