[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string[]] $ModuleName = @('MailChimp'),
    [Parameter()]
    [switch] $Bootstrap
)

if ($Bootstrap.IsPresent)
{
    if ($IsLinux)
    {
        sudo apt update 
        sudo apt install gh
    }
    
    $ModuleName | ForEach-Object {
        if (-not (Get-Module -ListAvailable -Name $_)) {
            Write-Verbose -Message "Installing module $_"
            $installParams = @{
                Name            = $_
                Repository      = 'PSGallery'
                Scope           = 'CurrentUser'
                Reinstall       = $true
                TrustRepository = $true
            }
            Install-PSResource @installParams
        }
    }
}  
