function New-GitHubReleaseLetter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $GitHubReleaseObject,

        [Parameter(Mandatory = $true)]
        [string]
        $GitHubReleaseLetterPath,

        [Parameter()]
        [string]
        $ModelName = "gpt-4o-mini",

        [Parameter()]
        [int]
        $MaxTokens = 500
    )

    # Get the latest release object
    $inputObject = Get-GitHubReleaseObject -GitHubReleaseObject $GitHubReleaseObject

    $featuredRelease = $inputObject | Get-Random -Count 1

    # Build message for feature release
    $messages = @(
        @{
            role    = "user"
            content = @(
                @{
                    type = "text"
                    text = "Can you represent a text that this is for a feature release. The content that I want you to summarize is: $($featuredRelease.body). Don't use any bullet points or lists. Don't make any assumptions. Don't mention the release number or what release it is. Output just a single paragraph. Keep it brief and maximum 50 words. Don't use any HTML tags."
                }
            )
        }
    )

    $completion = Invoke-OAIChatCompletion -Model $ModelName -Messages $messages -MaxTokens $MaxTokens

    $body = $completion.choices[0].message.content

    $featureRelease = ConvertTo-FeatureReleaseHtmTable -InputObject $featuredRelease -Body $body

    # Filter the releases based on the type of release
    $previewReleaseTable = $inputObject | Where-Object { $_.isPreRelease -eq $true } | ConvertTo-HtmlTable -IsPreRelease

    $majorReleaseTable = $inputObject | Where-Object { $_.isMajorRelease -eq $true } | ConvertTo-HtmlTable -IsMajorRelease

    $minorReleaseTable = $inputObject | Where-Object { $_.isMinorRelease -eq $true } | ConvertTo-HtmlTable -IsMinorRelease

    $patchReleaseTable = $inputObject | Where-Object { $_.isPatchRelease -eq $true } | ConvertTo-HtmlTable -IsPatchRelease

    # Combine all the tables into a single HTML string
    $htmlContent = Get-Content -Path $GitHubReleaseLetterPath -Raw
    $htmlContent = $htmlContent -replace "_{featured_release}_", $featureRelease
    $htmlContent = $htmlContent -replace "_{preview_releases}_", $previewReleaseTable
    $htmlContent = $htmlContent -replace "_{major_releases}_", $majorReleaseTable
    $htmlContent = $htmlContent -replace "_{minor_releases}_", $minorReleaseTable
    $htmlContent = $htmlContent -replace "_{patch_releases}_", $patchReleaseTable

    # Summary table
    $summaryTable = ConvertTo-SummaryHtmlTable -InputObject $inputObject
    $htmlContent = $htmlContent -replace "_{summary_table}_", $summaryTable

    # The week
    $week = Get-ISO8601Week
    $htmlContent = $htmlContent -replace "_{week}_", $week

    # Notable features
    $notableFeature = Get-NotableFeature -InputObject $inputObject
    $htmlContent = $htmlContent -replace "_{notable_features}_", $notableFeature

    return $htmlContent
}

function Get-NotableFeature {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject[]]
        $InputObject,

        [Parameter()]
        [string]
        $ModelName = "gpt-4o-mini"
    )

    $featureRelease = $InputObject | Get-Random -Count 5

    $htmlContent = @"
<tr>
    <td style="padding: 0 20px 20px;">
        <h3 class="section-title">Notable New Features</h3>
        <table width="100%" cellspacing="0" cellpadding="0" border="0">
"@

    foreach ($feature in $featureRelease) {
        Write-Verbose -Message "Getting notable feature release with:"
        Write-Verbose -Message ($feature | ConvertTo-Json | Out-String)

        $lineNumber = 1
        $result = @()

        $feature.body -split "`n" | ForEach-Object {
            if ($_ -match "https://github\.com/[^/]+/[^/]+/pull/\d+") {
                $result += [PSCustomObject]@{
                    LineNumber = $lineNumber
                    Line       = $_
                    URL        = $matches[0]
                }
            }
            $lineNumber++
        }

        if ($result) {
            # Create JSON object
            $json = $result | Sort-Object -Property line -Unique | Select-Object -ExpandProperty line | ConvertTo-Json

            $text = "I got the following JSON: $json. These represent new features. Can you pick one of them and remove the author and GitHub url. Make it a single line. No bullet points or lists."

            $messages = @(
                @{
                    role    = "user"
                    content = @(
                        @{
                            type = "text"
                            text = $text
                        }
                    )
                }
            )
            try {
                $completion = Invoke-OAIChatCompletion -Model $ModelName -Messages $messages -MaxTokens 100 -Verbose
                $content = $completion.choices[0].message.content

                $htmlContent += @"
<tr>
    <td style="padding: 0 0 15px;">
        <table width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#1a1a1a" style="border: 1px solid #ffd54e; border-radius: 8px; overflow: hidden;">
            <tr>
                <td style="padding: 15px;">
                    <h4 style="margin: 0 0 10px; color: #4bd5ee;">$($feature.repository): $($feature.name)</h4>
                    <p style="margin: 0; color: #ffd54e;">$content</p>
                </td>
            </tr>
        </table>
    </td>
"@
            }
            catch {
                Write-Warning -Message "Failed to convert JSON: $_"
                continue
            }

            
        }
    }

    $htmlContent += @"
        </table>
    </td>
</tr>
"@

    return $htmlContent
}


function Get-GitHubReleaseObject {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject])]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $GitHubReleaseObject
    )

    $currentDate = (Get-Date).AddDays(-7)

    $inputObject = New-Object 'System.Collections.Generic.List[System.Management.Automation.PSObject]'

    foreach ($gitHubRelease in $GitHubReleaseObject.GetEnumerator()) {
        Write-Verbose "Getting GitHub release object with:"
        Write-Verbose ($gitHubRelease | ConvertTo-Json | Out-String)
        try {
            $releases = Get-GitHubRelease @gitHubRelease -ErrorAction Stop
        }
        catch {
            Write-Warning -Message "Failed to get releases for $($gitHubRelease.Repository): $_"
        }

        $latestRelease = $releases | Where-Object { $_.published_at -gt $currentDate }

        if ($latestRelease.Count -eq 0) {
            Write-Verbose "No releases found in $($gitHubRelease.Repository) repo. Skipping."
        }

        foreach ($release in $latestRelease) {
            $out = [PSCustomObject]@{
                repository     = $gitHubRelease.Repository
                name           = $release.tag_name
                isPreRelease   = $release.prerelease
                isMajorRelease = $false 
                isMinorRelease = $false
                isPatchRelease = $false
                publishedAt    = ($release.published_at).ToString("MMMM d, yyyy")
                body           = $release.body
                url            = $release.html_url
            }

            if ($release.prerelease) {
                $out.isPreRelease = $true

                $inputObject.Add($out)
            }
            else {
                $penultimateRelease = $releases | Where-Object { $_.prerelease -ne $true -and $_.draft -ne $true -and $_.name -ne $release.name } | Select-Object -First 1

                [System.Management.Automation.SemanticVersion]$latestVersion = $release.tag_name.Remove(0, 1)
                [System.Management.Automation.SemanticVersion]$penultimateVersion = $penultimateRelease.tag_name.Remove(0, 1)
            
                # Determine what part of the version was incremented
                if ($latestVersion.Major -gt $penultimateVersion.Major) {
                    Write-Verbose "Major version incremented: $($penultimateVersion.Major) -> $($latestVersion.Major)"
                    $out.isMajorRelease = $true
                }
                elseif ($latestVersion.Minor -gt $penultimateVersion.Minor) {
                    Write-Verbose "Minor version incremented: $($penultimateVersion.Minor) -> $($latestVersion.Minor)"
                    $out.isMinorRelease = $true
                }
                elseif ($latestVersion.Patch -gt $penultimateVersion.Patch) {
                    Write-Verbose "Patch version incremented: $($penultimateVersion.Patch) -> $($latestVersion.Patch)"
                    $out.isPatchRelease = $true
                }

                else {
                    Write-Verbose "No version increment detected."
                }

                $inputObject.Add($out)
            }
        }
    }

    return $inputObject
}

function ConvertTo-SummaryHtmlTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject[]]
        $InputObject
    )

    $majorReleases = $InputObject | Where-Object { $_.isMajorRelease -eq $true } | Measure-Object | Select-Object -ExpandProperty Count 
    $minorReleases = $InputObject | Where-Object { $_.isMinorRelease -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    $patchReleases = $InputObject | Where-Object { $_.isPatchRelease -eq $true } | Measure-Object | Select-Object -ExpandProperty Count
    $previewReleases = $InputObject | Where-Object { $_.isPreRelease -eq $true } | Measure-Object | Select-Object -ExpandProperty Count

    $githubProjectCount = $InputObject | Select-Object -ExpandProperty repository | Get-Unique | Measure-Object | Select-Object -ExpandProperty Count
    $totalReleases = $InputObject | Measure-Object | Select-Object -ExpandProperty Count

    $htmlTable = @"
<tr>
            <td style="padding: 20px;">
                <table width="100%" cellspacing="0" cellpadding="0" border="0">
                    <tr>
                        <td>
                            <h2 style="color: #ffd54e; margin-top: 0; margin-bottom: 10px; font-size: 22px; text-transform: uppercase; letter-spacing: 2px;">👋 Greetings, Jedi</h2>
                            <p style="margin-top: 0; margin-bottom: 10px; line-height: 1.6; color: #ffd54e;">Welcome to the GitHub Galaxy Releases! Your weekly transmission of the most important project releases across the open-source universe.</p>
                            <p style="margin-top: 0; margin-bottom: 0; line-height: 1.6; color: #ffd54e;">This cycle we've tracked <strong style="color: #4bd5ee;">$totalReleases new releases</strong> across $githubProjectCount popular GitHub projects. Below you'll find intelligence on the most significant updates to help guide your development journey.</p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
<tr>
                <td style="padding: 0 20px 20px;">
                    <h3 class="section-title">Release Summary</h3>
                    <table width="100%" cellspacing="0" cellpadding="0" border="0" style="border: 1px solid #ffd54e; border-radius: 8px; overflow: hidden;">
                        <tr>
                            <th style="background-color: #333; color: #ffd54e; text-align: left; padding: 12px 15px; font-weight: 600; text-transform: uppercase; border-bottom: 1px solid #ffd54e;">Release Type</th>
                            <th style="background-color: #333; color: #ffd54e; text-align: left; padding: 12px 15px; font-weight: 600; text-transform: uppercase; border-bottom: 1px solid #ffd54e;">Count</th>
                        </tr>
                        <tr>
                            <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">Major Releases</td>
                            <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">$majorReleases</td>
                        </tr>
                        <tr bgcolor="#1a1a1a">
                            <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">Minor Releases</td>
                            <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">$minorReleases</td>
                        </tr>
                        <tr>
                            <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">Patch Releases</td>
                            <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">$patchReleases</td>
                        </tr>
                        <tr bgcolor="#1a1a1a">
                            <td style="padding: 12px 15px; border-bottom: 0; color: #ffd54e;">Preview Releases</td>
                            <td style="padding: 12px 15px; border-bottom: 0; color: #ffd54e;">$previewReleases</td>
                        </tr>
                    </table>
                </td>
            </tr>
"@
    return $htmlTable
}

function ConvertTo-FeatureReleaseHtmTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject[]]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Body

    )

    if ($InputObject.isMajorRelease) {
        $badgeText = "badge-major"
        $badge = "MAJOR"
    }
    elseif ($InputObject.isMinorRelease) {
        $badgeText = "badge-minor"
        $badge = "MINOR"
    }
    elseif ($InputObject.isPatchRelease) {
        $badgeText = "badge-patch"
        $badge = "PATCH"
    }
    elseif ($InputObject.isPreRelease) {
        $badgeText = "badge-preview"
        $badge = "PREVIEW"
    }
    else {
        $badgeText = "badge-default"
        $badge = "DEFAULT"
    }

    $htmlTable = @"
<tr>
    <td style="padding: 0 20px 20px;">
        <h3 class="section-title">Featured Release</h3>
        <table width="100%" cellspacing="0" cellpadding="0" border="0" style="border: 1px solid #ff0000; border-radius: 8px; overflow: hidden; background-color: rgba(255, 0, 0, 0.1);">
            <tr>
                <td style="padding: 15px;">
                    <table width="100%" cellspacing="0" cellpadding="0" border="0">
                        <tr>
                            <td>
                                <h4 style="margin: 0 0 10px; color: #ffd54e;">$($InputObject.repository) $($InputObject.name)</h4>
                                <p style="margin: 0 0 5px; font-size: 14px; color: #ffd54e;">
                                    <span class="release-badge $badgeText">$badge</span>
                                    <span style="margin-left: 10px;">Released: $($InputObject.publishedAt)</span>
                                </p>
                                <p style="margin: 10px 0; color: #ffd54e;">$Body</p>
                                <p style="margin: 0; color: #ffd54e;"><a href="$($InputObject.url)" target="_blank" style="color: #4bd5ee; text-decoration: none;">View Release Notes →</a></p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
        </table>
    </td>
</tr>
"@
    return $htmlTable
}

function ConvertTo-HtmlTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $InputObject,

        [Parameter()]
        [switch]
        $IsPreRelease,

        [Parameter()]
        [switch]
        $IsMajorRelease,

        [Parameter()]
        [switch]
        $IsMinorRelease,

        [Parameter()]
        [switch]
        $IsPatchRelease
    )

    begin {
        if ($IsPreRelease.IsPresent) {
            $headingText = "Preview Releases"
            $badgeText = "badge-preview"
        }
        elseif ($IsMajorRelease.IsPresent) {
            $headingText = "Major Releases"
            $badgeText = "badge-major"
        }
        elseif ($IsMinorRelease.IsPresent) {
            $headingText = "Minor Releases"
            $badgeText = "badge-minor"
        }
        elseif ($IsPatchRelease.IsPresent) {
            $headingText = "Patch Releases"
            $badgeText = "badge-patch"
        }
        else {
            $headingText = "Releases"
            $badgeText = "badge-default"
        }

        $htmlTable = @"
<tr>
    <td style="padding: 0 20px 20px;">
        <h3 class="section-title">$headingText</h3>
        <table width="100%" cellspacing="0" cellpadding="0" border="0" style="border: 1px solid #ffd54e; border-radius: 8px; overflow: hidden;">
            <tr>
                <th style="background-color: #333; color: #ffd54e; text-align: left; padding: 12px 15px; font-weight: 600; text-transform: uppercase; border-bottom: 1px solid #ffd54e;">Project</th>
                <th style="background-color: #333; color: #ffd54e; text-align: left; padding: 12px 15px; font-weight: 600; text-transform: uppercase; border-bottom: 1px solid #ffd54e;">Version</th>
                <th style="background-color: #333; color: #ffd54e; text-align: left; padding: 12px 15px; font-weight: 600; text-transform: uppercase; border-bottom: 1px solid #ffd54e;">Released</th>
                <th style="background-color: #333; color: #ffd54e; text-align: left; padding: 12px 15px; font-weight: 600; text-transform: uppercase; border-bottom: 1px solid #ffd54e;">Details</th>
            </tr>
"@
    }

    process {
        

        foreach ($release in $InputObject) {
            $htmlTable += @"
            <tr>
                <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">$($release.repository)</td>
                <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;"><span class="release-badge $badgeText">$($release.name)</span></td>
                <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;">$($release.publishedAt)</td>
                <td style="padding: 12px 15px; border-bottom: 1px solid #333; color: #ffd54e;"><a href="$($release.url)" target="_blank" style="color: #4bd5ee; text-decoration: none;">View</a></td>
            </tr>
"@
        }
    }

    end {
        $htmlTable += @"
        </table>
    </td>
</tr>
"@

        return $htmlTable
    }
}

function Get-ISO8601Week {
    Param(
        [datetime]$DT = (Get-Date)
    )
    $Cult = Get-Culture; $DT = Get-Date($DT)
    $WeekRule = $Cult.DateTimeFormat.CalendarWeekRule.value__
    $FirstDayOfWeek = $Cult.DateTimeFormat.FirstDayOfWeek.value__
    $WeekRuleDay = [int]($DT.DayOfWeek.Value__ -ge $FirstDayOfWeek ) * ( (6 - $WeekRule) - $DT.DayOfWeek.Value__ )
    $Cult.Calendar.GetWeekOfYear(($DT).AddDays($WeekRuleDay), $WeekRule, $FirstDayOfWeek)
}