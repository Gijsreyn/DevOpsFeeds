#Requires -Version 7.0
<#
.SYNOPSIS
    Mints a short-lived GitHub App installation access token.

.DESCRIPTION
    Builds an RS256-signed JWT from the GitHub App's private key, then exchanges it
    for an installation access token (valid for 1 hour). The token is written to the
    pipeline as the only output so callers can capture it, e.g.:

        $env:GH_TOKEN = ./Get-GitHubAppToken.ps1 -ClientId $clientId -PrivateKeyPath ./app.pem

.PARAMETER ClientId
    The GitHub App's Client ID (or App ID).

.PARAMETER PrivateKeyPath
    Path to the App's private key in PEM format.

.PARAMETER InstallationId
    Optional installation id. When omitted, the first installation of the App is used.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $ClientId,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string] $PrivateKeyPath,

    [Parameter()]
    [string] $InstallationId
)

$ErrorActionPreference = 'Stop'

function ConvertTo-Base64Url {
    param ([Parameter(Mandatory)] [byte[]] $Bytes)
    [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

# Build the JWT: iat backdated 60s to allow for clock drift, 9 minute expiry (max is 10)
$now = [DateTimeOffset]::UtcNow
$header = ConvertTo-Base64Url -Bytes ([Text.Encoding]::UTF8.GetBytes((@{ alg = 'RS256'; typ = 'JWT' } | ConvertTo-Json -Compress)))
$payload = ConvertTo-Base64Url -Bytes ([Text.Encoding]::UTF8.GetBytes((@{
    iat = $now.AddSeconds(-60).ToUnixTimeSeconds()
    exp = $now.AddMinutes(9).ToUnixTimeSeconds()
    iss = $ClientId
} | ConvertTo-Json -Compress)))

$rsa = [System.Security.Cryptography.RSA]::Create()
try {
    $rsa.ImportFromPem((Get-Content -Path $PrivateKeyPath -Raw))
    $signature = ConvertTo-Base64Url -Bytes $rsa.SignData(
        [Text.Encoding]::UTF8.GetBytes("$header.$payload"),
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
finally {
    $rsa.Dispose()
}
$jwt = "$header.$payload.$signature"

$apiHeaders = @{
    Authorization          = "Bearer $jwt"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

if (-not $InstallationId) {
    $installations = Invoke-RestMethod -Uri 'https://api.github.com/app/installations' -Headers $apiHeaders
    if (-not $installations) {
        throw 'The GitHub App has no installations. Install the App on an account first.'
    }
    $InstallationId = $installations[0].id
    Write-Verbose -Message "Using installation id $InstallationId"
}

$response = Invoke-RestMethod -Uri "https://api.github.com/app/installations/$InstallationId/access_tokens" -Method Post -Headers $apiHeaders

# Output the token only; never log it
$response.token
