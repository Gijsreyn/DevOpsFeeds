@{
    RootModule           = 'MailChimp.psm1'
    ModuleVersion        = '0.1.3'
    GUID                 = '8250d1e0-52d4-4ff4-b58a-f681e7ecf054'
    Author               = 'Gijs Reijn'
    Description          = 'MailChimp module for PowerShell to create campaigns and update content'
    PowerShellVersion    = '7.2'
    FunctionsToExport    = @(
        'New-MailChimpCampaign',
        'Update-MailChimpCampaign',
        'Get-MailChimpCampaignContent',
        'Connect-MailChimpApi',
        'Get-MailChimpList',
        'Get-MailChimpCampaign',
        'Send-MailChimpCampaign'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'MailChimp', 'Campaign', 'Content'
            )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/gijsreijn/devopsfeeds/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/gijsreijn/devopsfeeds/'

            # A URL to an icon representing this module.
            IconUri = 'https://raw.githubusercontent.com/Gijsreyn/devopsfeeds/main/.images/mailchimp-icon-50px.png'

        }
    }
}