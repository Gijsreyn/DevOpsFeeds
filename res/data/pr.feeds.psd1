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
            State = 'Open' # filter to not get all available PRs
            Filter = @{
                User = @('dependabot[bot]')
            }
        }
    )
}