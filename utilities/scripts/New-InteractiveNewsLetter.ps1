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

    $newsLetter = $newsLetter -replace '_{totalPullRequests}_', $pullRequestData.Count

    $newsLetter = $newsLetter -replace '_{totalCategories}_', $RepositoryList.category.Count

    # Get category header
    $categoryCounter = Get-CategoryCounter -InputObject $pullRequestData
    $newsLetter = $NewsLetter -replace '{table__countersummary}', $categoryCounter

    # Get body table
    $bodyTable = Get-BodyTable -InputObject $pullRequestData
    $newsLetter = $NewsLetter -replace '{table__body}', $bodyTable

    # Replace the date
    $getCurrentWeekNumber = Get-ISO8601Week
    $newsLetter = $NewsLetter -replace '_{currentDate}_', "Week $getCurrentWeekNumber"

    return $newsLetter
}

function Get-ISO8601Week {
    Param(
    [datetime]$DT = (Get-Date)
    )
    <#
    First create an integer(0/1) from the boolean,
    "Is the integer DayOfWeek value greater than zero?".
    Then Multiply it with 4 or 6 (weekrule = 0 or 2) minus the integer DayOfWeek value.
    This turns every day (except Sunday) into Thursday.
    Then return the ISO8601 WeekNumber.
    #>
    $Cult = Get-Culture; $DT = Get-Date($DT)
    $WeekRule = $Cult.DateTimeFormat.CalendarWeekRule.value__
    $FirstDayOfWeek = $Cult.DateTimeFormat.FirstDayOfWeek.value__
    $WeekRuleDay = [int]($DT.DayOfWeek.Value__ -ge $FirstDayOfWeek ) * ( (6 - $WeekRule) - $DT.DayOfWeek.Value__ )
    $Cult.Calendar.GetWeekOfYear(($DT).AddDays($WeekRuleDay), $WeekRule, $FirstDayOfWeek)
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
                "title,body,url,state,author,updatedAt",
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
                        # Get the date difference in days
                        $currentDate = Get-Date
                        $daysDifference = ($_.updatedAt - $currentDate).Days

                        $updatedAt = 'today'
                        if ($daysDifference -lt 0) {
                            $updatedAt =  "$([Math]::Abs($daysDifference)) days ago"

                            if ($updatedAt -eq '7 days ago') {
                                $updatedAt = '1 week ago'
                            }
                        } 

                        $inputObject.Add([PSCustomObject]@{
                                Owner      = $list.Owner
                                Repository = $list.Repository
                                Title      = $_.title
                                Author     = $_.author.login
                                State      = $_.state
                                HtmlUrl    = $_.url
                                UpdatedAt  = $updatedAt
                                Category   = $list.Category
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

        $groupIndex = 0
        foreach ($group in $groups) {
            Write-Verbose -Message "Processing group: $($group.Name)"
            $theadId = ($group.Name -replace " ", "-").ToLower()
            $groupIndex++
            $borderStyle = ($groupIndex -lt $groups.Count) ? 'border-bottom: 1px solid #f1ece5;' : ''
            $indexNumber = "{0:d2}" -f $groupIndex
            $prLabel = ($group.Count -eq 1) ? 'PR' : 'PRs'
            $contentCounter += @"
            <tr>
                <td width="34" valign="middle" style="padding: 13px 0 13px 20px; $borderStyle"><span style="font-family: Consolas, 'Courier New', monospace; font-size: 12px; font-weight: 700; color: #c9c2b8;">$indexNumber</span></td>
                <td valign="middle" style="padding: 13px 8px 13px 6px; $borderStyle"><a href="#$($theadId)" style="color: #23272f; font-size: 14.5px; font-weight: 600; text-decoration: none;">$($group.Name)</a></td>
                <td align="right" valign="middle" style="padding: 13px 20px 13px 0; white-space: nowrap; $borderStyle"><a href="#$($theadId)" style="text-decoration: none;"><span style="display: inline-block; min-width: 20px; padding: 3px 11px; border-radius: 999px; background-color: #fff3ed; color: #e04e2c; font-size: 12.5px; font-weight: 700; text-align: center;">$($group.Count) $prLabel</span>&nbsp;<span style="color: #c9c2b8; font-size: 16px; font-weight: 700;">&rsaquo;</span></a></td>
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

        # Tinted GitHub-style status pills plus a row accent color; keyed on the lowercase PR state
        $statusStyles = @{
            open   = @{ Pill = 'background-color: #e7f6ec; color: #1a7f37;'; Accent = '#2da44e' }
            merged = @{ Pill = 'background-color: #f3ebff; color: #7c3aed;'; Accent = '#8250df' }
            closed = @{ Pill = 'background-color: #ffebe9; color: #cf222e;'; Accent = '#cf222e' }
        }
        $defaultStatusStyle = @{ Pill = 'background-color: #eceef1; color: #57606a;'; Accent = '#afb8c1' }

        $content = @()
        foreach ($group in $groups) {
            Write-Verbose -Message "Processing group: $($group.Name)"
            $theadId = ($group.Name -replace " ", "-").ToLower()
            $content += @"
            <table width="100%" cellpadding="0" cellspacing="0" border="0" style="width: 100%; margin: 0 0 22px; background-color: #ffffff; border: 1px solid #e9e3db; border-radius: 14px; overflow: hidden;">
            <tr id="$theadId">
                <td style="padding: 15px 20px; background-color: #faf7f3; border-bottom: 1px solid #e9e3db;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                        <tr>
                            <td>
                                <span style="font-size: 16px; font-weight: 700; color: #23272f;">$($group.Name)</span>
                                <span style="display: inline-block; margin-left: 8px; padding: 3px 11px; border-radius: 999px; background-color: #fff3ed; color: #e04e2c; font-size: 12px; font-weight: 700; vertical-align: middle;">$($group.Count) new</span>
                            </td>
                            <td align="right" valign="middle"><a href="#top" style="font-size: 12px; font-weight: 600; color: #b0a99e; text-decoration: none; white-space: nowrap;">Top &uarr;</a></td>
                        </tr>
                    </table>
                </td>
            </tr>
"@

            $itemIndex = 0
            foreach ($item in $group.Group) {
                $state = $item.State.ToLower()
                $statusStyle = $statusStyles.ContainsKey($state) ? $statusStyles[$state] : $defaultStatusStyle
                $itemIndex++
                $borderStyle = ($itemIndex -lt $group.Count) ? 'border-bottom: 1px solid #f1ece5;' : ''
                $content += @"
                <tr>
                    <td valign="top" style="padding: 14px 20px 15px 17px; border-left: 3px solid $($statusStyle.Accent); $borderStyle">
                        <a href="$($item.HtmlUrl)" target="_blank" style="display: block; color: #23272f; font-size: 14.5px; font-weight: 600; line-height: 1.45; text-decoration: none;">$($item.Title)</a>
                        <div style="margin-top: 7px; font-size: 12px; line-height: 2; color: #8a8f98;">
                            <span style="display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.4px; vertical-align: middle; $($statusStyle.Pill)"><span style="font-size: 8px; vertical-align: 1px;">&#9679;</span>&nbsp;$(( Get-Culture ).TextInfo.ToTitleCase( $state ))</span>
                            <span style="display: inline-block; margin-left: 4px; padding: 2px 8px; border-radius: 6px; background-color: #f6f3ee; border: 1px solid #eee8df; font-family: Consolas, 'Courier New', monospace; font-size: 11px; color: #6a7180; vertical-align: middle;">$($item.Owner)/$($item.Repository)</span>
                            &nbsp;by <span style="color: #57606a; font-weight: 600;">$($item.Author)</span>&nbsp;&nbsp;&bull;&nbsp;&nbsp;$($item.UpdatedAt)
                        </div>
                    </td>
                </tr>
"@
            }

            $content += @"
                </table>
"@

        }
    }

    end {
        Write-Verbose "Ended: $($MyInvocation.MyCommand.Name)"

        return $content
    }
}