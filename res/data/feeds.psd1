@{
    feeds = @(
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
            Owner = 'radius-project'
            Repository = 'radius'
            Category = 'Platform Engineering'
            State = 'Open'
            Filter = @{
                User = @('dependabot[bot]')
            }
        }
    )
}