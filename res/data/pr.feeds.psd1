@{
    feeds = @(
        #region PowerShell repositoriess
        @{
            Owner = 'PowerShell'
            Repository = 'DSC'
            Category = 'Configuration Management'
        }
        @{
            Owner = 'PowerShell'
            Repository = 'platyPS'
            Category = 'Automation'
        }
        @{
            Owner = 'PowerShell'
            Repository = 'platyPS'
            Category = 'Automation'
        }
        @{
            Owner = 'PowerShell'
            Repository = 'PSResourceGet'
            Category = 'Automation'
        }
        #endRegion PowerShell repositories
        @{
            Owner = 'radius-project'
            Repository = 'radius'
            Category = 'Platform Engineering'
            Filter = @{
                User = @('dependabot[bot]')
            }
        }
        @{
            Owner = 'Azure'
            Repository = 'bicep'
            Category = 'Infrastructure as Code'
            Filter = @{
                User = @('dependabot[bot]')
            }
        }
    )
}