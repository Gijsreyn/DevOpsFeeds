function New-InteractiveNewsLetter {
    <#
    .SYNOPSIS
        Generates a new interactive MailChimp newsletter based on GitHub pull request data.

    .DESCRIPTION
        The `New-InteractiveNewsLetter` function creates a new interactive MailChimp newsletter by fetching GitHub pull request data from specified repositories and formatting it into a newsletter template. The function reads a list of feeds from a PowerShell data file, retrieves pull request data using a GitHub personal access token, and replaces placeholders in a newsletter template with the retrieved data.

    .PARAMETER RepositoryList
        The list of repositories to fetch pull request data from. This parameter is optional.

    .PARAMETER NewsLetterFile
        The path to the file containing the newsletter template. This parameter is .optional

    .EXAMPLE
        PS C:\> New-InteractiveNewsLetter -RepositoryList @{"Owner"="PowerShell"; "Repository"="PowerShell"; "Category"="Automation"} -NewsLetterFile "interactive.html"

        This example generates a new interactive HTML newsletter content using the specified repository list and newsletter template file.

    #>
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $false)]
        [hashtable[]] $RepositoryList,

        [Parameter(Mandatory = $false)]
        [string] $NewsLetterFile
    )

    if (-not (Test-Path $NewsLetterFile -ErrorAction SilentlyContinue)) {
        Write-Verbose -Message "The file $NewsLetterFile does not exist."
        return
    }

    if (($null -eq $RepositoryList) -or (!($RepositoryList.ContainsKey('Owner')) -and !($RepositoryList.ContainsKey('Repository')) -and !($RepositoryList.ContainsKey('Category')))) {
        Write-Verbose -Message "RepositoryList is not in the correct format. Please provide a list of repositories in the correct format."
        return
    }

    $newsLetter = Get-Content $NewsLetterFile -Raw

    $pullRequestData = Get-GHCliPullRequestData -RepositoryList $RepositoryList

    # Get category header
    $categoryCounter = Get-CategoryCounter -InputObject $pullRequestData
    $newsLetter = $NewsLetter -replace '{table__countersummary}', $categoryCounter

    # Get body table
    $bodyTable = Get-BodyTable -InputObject $pullRequestData
    $newsLetter = $NewsLetter -replace '{table__body}', $bodyTable

    # Replace the date
    $currentDate = (Get-Date).ToString('MMMM dd, yyyy')
    $newsLetter = $NewsLetter -replace '{currentDate}', $currentDate

    return $newsLetter
}

function Get-GHCliPullRequestData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]] $RepositoryList
    )
    
    begin {
        Write-Verbose "Started: $($MyInvocation.MyCommand.Name)"
        $inputObject = [System.Collections.Generic.List[pscustomobject]]::new()
    }

    process {
        foreach ($list in $RepositoryList) {
            $previousWeek = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')
            $searchQuery = "created:>$previousWeek"

            $arguments = @(
                "pr",
                "list",
                "--repo",
                ("{0}/{1}" -f $list.Owner, $list.Repository),
                "--json",
                "title,body,url,state,author",
                "--search",
                $searchQuery,
                "--state",
                "All"
            )

            Write-Verbose -Message ("Running with arguments:")
            Write-Verbose -Message ($arguments | ConvertTo-Json | Out-String)

            $pullRequestData = gh @arguments | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($null -ne $pullRequestData) {
                $pullRequestData | ForEach-Object {
                    Write-Verbose -Message "Adding data for title: $($_.title) and repository: $($list.Repository)"
                    # $tempDescription = $_.body -replace '<!--.*?-->', '' -replace "`r`n", " " -replace "`n", " "
                    # $description = ($tempDescription.Length -gt 117) ? ($tempDescription.Substring(0, 117) + "...") : $tempDescription
                    # # Extra rule
                    # $description = $description -replace '<!--', ''
                    if (-not ($_.author.is_bot)) {
                        $inputObject.Add([PSCustomObject]@{
                            Owner       = $list.Owner
                            Repository  = $list.Repository
                            Title       = $_.title
                            Author     = $_.author.login
                            State       = $_.state
                            HtmlUrl     = $_.url
                            Category    = $list.Category
                        })
                    }
                }
            }
        }
    }
    
    end {
        Write-Verbose "Ended: $($MyInvocation.MyCommand.Name)"
        return $inputObject
    }
}

function Get-CategoryCounter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]] $InputObject
    )
    
    begin {
        Write-Verbose "Started: $($MyInvocation.MyCommand)"
    }

    process {
        $groups = $InputObject | Group-Object -Property Category

        foreach ($group in $groups) {
            Write-Verbose -Message "Processing group: $($group.Name)"
            $theadId = ($group.Name -replace " ", "-").ToLower()
            $contentCounter += @"
            <tr>
                <td style="text-align: left; background-color: white;">
                    <a href="#$theadId">$($group.Name)</a>
                </td>
                <td style="text-align: right; background-color: white;">$($group.Count)</td>
            </tr>
"@        
        }
    }

    end {
        Write-Verbose "Ended: $($MyInvocation.MyCommand.Name)"

        return $contentCounter
    }
}

function Get-BodyTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]] $InputObject
    )

    begin {
        Write-Verbose "Started: $($MyInvocation.MyCommand)"
    }

    process {
        $groups = $InputObject | Group-Object -Property Category

        $content = @()
        foreach ($group in $groups) {
            Write-Verbose -Message "Processing group: $($group.Name)"
            $theadId = ($group.Name -replace " ", "-").ToLower()
            $content += @"
            <thead id="$theadId">
            <tr>
                <th colspan="5" class="config-header">
                    $($group.Name.ToUpper()) ($($group.Count) UPDATES)
                </th>
            </tr>
            <tr>
                <th>Title</th>
                <th>URL</th>                
                <th>Repository</th>
                <th>Author</th>
                <th>Status</th>
            </tr>
"@

            foreach ($item in $group.Group) {
                $content += @"
                <tbody>
                <tr>
                    <td>$($item.Title)</td>
                    <td><a href="$($item.HtmlUrl)" target="_blank">$($item.HtmlUrl)</a></td>
                    <td>$($item.Owner)/$($item.Repository)</td>
                    <td>$($item.Author)</td>
                    <td>
                        <p class="status $($item.State.ToLower())">$(( Get-Culture ).TextInfo.ToTitleCase( $item.State.ToLower()) )</p>
                    </td>
                </tr>
"@            
            }
            
            $content += @"
            </thead>
"@
        }
    }

    end {
        Write-Verbose "Ended: $($MyInvocation.MyCommand.Name)"

        return $content
    }
}