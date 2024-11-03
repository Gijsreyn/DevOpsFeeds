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
            Repository = 'PSResourceGet'
            Category = 'Automation'
        }
        #endRegion PowerShell repositories
        @{
            Owner = 'radius-project'
            Repository = 'radius'
            Category = 'Platform Engineering'
            Filter = @{
                User = @('dependabot')
            }
        }
        @{
            Owner = 'Azure'
            Repository = 'bicep'
            Category = 'Infrastructure as Code'
            Filter = @{
                User = @('dependabot')
            }
        }
        @{
            Owner = 'ansible'
            Repository = 'ansible'
            Category = 'Configuration Management'
        }
        @{
            Owner = 'opentofu'
            Repository = 'opentofu'
            Category = 'Infrastructure as Code'
        }
        @{
            Owner = 'grafana'
            Repository = 'loki'
            Category = 'Log aggregation and management'
        }
        @{
            Owner = 'prometheus'
            Repository = 'prometheus'
            Category = 'Monitoring and alerting'
        }
    )
}
