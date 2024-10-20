
function New-MailChimpNewsLetter {
    <#
    .SYNOPSIS
        Generates a new MailChimp newsletter based on GitHub pull request data.

    .DESCRIPTION
        The `New-MailChimpNewsLetter` function creates a new MailChimp newsletter by fetching GitHub pull request data from specified repositories and formatting it into a newsletter template. The function reads a list of feeds from a PowerShell data file, retrieves pull request data using a GitHub personal access token, and replaces placeholders in a newsletter template with the retrieved data.

    .PARAMETER FeedList
        The path to the PowerShell data file containing the list of feeds (repositories) to fetch pull request data from. This parameter is optional.

    .PARAMETER AccessToken
        The GitHub personal access token used to authenticate API requests. This parameter is mandatory.

    .PARAMETER NewsLetterFile
        The path to the file containing the newsletter template. This parameter is mandatory.

    .EXAMPLE
        PS> New-MailChimpNewsLetter -FeedList "C:\feeds.psd1" -AccessToken "ghp_YourAccessToken" -NewsLetterFile "C:\newsletter.html"

        This example generates a new MailChimp newsletter using the specified feed list, access token, and newsletter template file.

    #>
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $false)]
        [string] $FeedList = (Join-Path "$PSScriptRoot/../../" 'res' 'data' 'pr.feeds.psd1'),

        [Parameter(Mandatory = $true)]
        [string] $AccessToken,

        [Parameter(Mandatory = $false)]
        [string] $NewsLetterFile = (Join-Path "$PSScriptRoot/../../" 'res' 'templates' 'html' 'basic.pr.template.html')
    )

    if (-not (Test-Path $NewsLetterFile -ErrorAction SilentlyContinue)) {
        return
    }

    $newsLetter = Get-Content $NewsLetterFile -Raw

    $feedData = Import-PowerShellDataFile -Path $FeedList

    $gitHubData = Get-GitHubPullRequestData -Feeds $feedData.feeds -AccessToken $accessToken

    # get header
    $header = Get-NewsletterHeader
    $newsLetter = $NewsLetter -replace '{header}', $header

    # article counter
    $articleCount = Get-NewsLetterUpdateCount -inputObject $gitHubData
    $NewsLetter = $NewsLetter -replace '{articleCount}', $articleCount

    # get content
    $content = Get-NewsletterContent -inputObject $gitHubData
    $NewsLetter = $NewsLetter -replace '{content}', $content

    return $NewsLetter
}

function Get-GitHubPullRequestData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]] $Feeds,

        [Parameter(Mandatory = $true)]
        [string] $AccessToken
    )

    begin {
        Write-Verbose "Started: $($MyInvocation.MyCommand.Name)"

        if (-not ($AccessToken.StartsWith('ghp_'))) {
            Throw "Please specify a valid GitHub Personal Access Token"
        }

        # holds PR data
        $inputObject = [System.Collections.Generic.List[pscustomobject]]::new()
    }

    process {
        foreach ($feed in $Feeds) {
            $params = @{
                OwnerName      = $feed.Owner 
                RepositoryName = $feed.Repository
                State          = 'All'
            }

            if ($feed.ContainsKey('State')) {
                Write-Verbose -Message "Setting state to: $($feed.State) to fetch pull requests"
                $params.State = $feed.State
            }

            $previousWeek = (Get-Date).AddDays(-7)
            $currentDay = (Get-Date).ToString('yyyy-MM-dd')
            Write-Verbose "Retrieving pull requests for $($feed.Owner)/$($feed.Repository)"
            # using GraphQL to reduce amount of data fetched
            $grahpQlQuery = @"
{
  search(first: 100, query: "repo:PowerShell/DSC is:pr is:open updated:$($previousWeek.ToString('yyyy-MM-dd'))..$currentDay", type: ISSUE) {
    nodes {
      ... on PullRequest {
        title
        url
        state
        author {
          login
        }
        repository {
            nameWithOwner
            name
            url
          }
        createdAt
      }
    }
  }
}
"@
            $authenticationToken = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$accessToken"))
            $headers = @{
                "Authorization" = [String]::Format("Basic {0}", $authenticationToken)
                "Content-Type"  = "application/json"
            }

            $body = @{query=$grahpQlQuery} | ConvertTo-Json
            $res = Invoke-RestMethod "https://api.github.com/graphql" -Headers $headers -Body $body -Method Post

            # TODO: make better filter
            if ($feed.ContainsKey('Filter')) {
                if ($null -ne $feed.Filter.User)
                {
                    Write-Verbose -Message "Applying filter: $($feed.Filter.User) to PRs"
                    $prs = $prs | Where-Object { $_.user.Login -notin $feed.Filter.User }
                }
            }

            $res.data.search.nodes | ForEach-Object {
                $OwnerName = $_.repository.nameWithOwner.Split("/")[0]
                $inputObject.Add([PSCustomObject]@{
                    Owner        = $OwnerName
                    Repository   = $_.repository.name
                    Title        = $_.title
                    State        = (Get-Culture).TextInfo.ToTitleCase($_.state.ToLower())
                    'Created by' = $_.author.login
                    'HtmlUrl'    = $_.url
                    RepositoryUrl = $_.repository.url
                    Category     = $feed.Category
                })
            }
        }
    }

    end {
        Write-Verbose "Ended: $($MyInvocation.MyCommand.Name)"
        
        return $inputObject
    }   
}


function Get-NewsletterHeader {
    $startDateString = (Get-Date).AddDays(-7).ToString("dddd dd yyyy")
    $endDateString = (Get-Date).ToString("dddd dd yyyy")

    return @"
<p>
<strong
><span
    style="
    font-size: 20px;
    "
    >Weekly
    update:
    $startDateString to
    $endDateString</span
></strong>
</p>
<p
style="
text-align: center;
"
>
<br />
</p>
"@
}

function Get-NewsLetterUpdateCount {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject[]] $inputObject
    )

    if (-not $inputObject) {
        return
    }

    $groups = $inputObject | Group-Object -Property Category

    $contentCounter = @"
<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse; width: 100%;">
    <thead>
        <tr style="background-color: #0047AB; color: white;">
            <th>Category</th>
            <th>Count</th>
        </tr>
    </thead>
    <tbody>
"@

    foreach ($group in $groups) {
        $contentCounter += @"
        <tr style="background-color: #F0FFFF;text-align: center;">
            <td><a href="#$($group.Name) Updates"> $($group.Name) </a></td>
            <td>$($group.Count)</td>
        </tr>
"@
    }

    $contentCounter += @"
    </tbody>
</table>
<br />
"@

    return $contentCounter
}

function Get-NewsletterContent {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject[]] $inputObject
    )

    if (-not $inputObject) {
        return
    }

    $groups = $inputObject | Group-Object -Property Category

    $content = @()
    foreach ($group in $groups) {
        Write-Verbose -Message "Processing group: $($group.Name)"

        $c += @"
        <tr style="background-color: $backgroundColor;">
            <td>$($group.Name)</td>
            <td>$($group.Count)</td>
        </tr>
"@

        $categoryString = @"
<div>
<p
    style="
    text-align: center;
    "
>
    <strong><span
        style="
        font-size: 18px;
        "
        ><em>$($group.Group.Category | Select-Object -First 1) Updates</em></span
    ></strong>
</p>
</div>
<br />
{0}
<br />
"@
        $tableData = New-HtmlTable -inputObject $group.Group
        $content += ($categoryString -f $tableData)
    }

    return $content
}

function New-HtmlTable {
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [pscustomobject[]]$inputObject
    )

    if (-not $inputObject) {
        return
    }

    $headerNames = $inputobject[0].PSObject.Properties | Where-Object { $_.Name -notin @('HtmlUrl', 'Category', 'RepositoryUrl') } | Select-Object -ExpandProperty Name
    $headerHtml = foreach ($headerName in $headerNames) {
        "<th>$headerName</th>"
    }

    $htmlString = @"
<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse; width: 100%;">
    <thead>
        <tr style="background-color: #0047AB; color: white;">
            $headerHtml
        </tr>
    </thead>
    <tbody>
"@

    $rowIndex = 0
    foreach ($item in $inputObject) {
        $backgroundColor = '#F0FFFF' #if ($rowIndex % 2 -eq 0) { "#89CFF0" } else { "#89CFF0" }
        $htmlString += @"
        <tr style="background-color: $backgroundColor;">
            <td>$($item.Owner)</td>
            <td><a href="$($item.Repositoryurl)" target="_blank">$($item.Repository)</a></td>
            <td><a href="$($item.Htmlurl)" target="_blank">$($item.Title)</a></td>
            <td>$(( Get-Culture ).TextInfo.ToTitleCase( $item.state.ToLower()) )</td>
            <td><a href="https://github.com/$($item.'Created by')" target="_blank">$($item.'Created by')</a></td>
        </tr>
"@
        $rowIndex++
    }

    $htmlString += @"
    </tbody>
</table>
"@

    return $htmlString
}