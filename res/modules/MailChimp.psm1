#region Functions

#region Private functions
Function Get-MailChimpApiData
{
    [CmdletBinding()]
    Param (
        $Endpoint
    )

    $Api = @{
        'Connect-MailChimpApi'    = @{
            '3.0' = @{
                Description = 'Connect to the MailChimp API'
                URI         = '<dc>.api.mailchimp.com/3.0/'
                Method      = 'Get'
                Body        = ''
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
        'New-MailChimpCampaign' = @{
            '3.0' = @{
                Description = 'Create new MailChimp campaign'
                URI         = 'campaigns'
                Method      = 'Post'
                Body        = [ordered]@{
                    type = "regular"
                    recipients = [ordered]@{
                        list_id = "listId"
                    }
                    settings = [ordered]@{
                        subject_line = "subjectLine"
                        preview_text = "previewText"
                        title = "title"
                        from_name = "fromName"
                        reply_to = "replyTo"
                        use_conversation = $false
                        to_name = "toName"
                        folder_id = "folderId"
                        authenticate = $true
                        auto_footer = $false
                        inline_css = $false
                        auto_tweet = $false
                        fb_comments = $false
                        template_id = 0
                    }
                    tracking = [ordered]@{
                        opens = $false
                        html_clicks = $false
                        text_clicks = $false
                        goal_tracking = $false
                        ecomm360 = $false
                        google_analytics = "googleAnalytics"
                        clicktale = "clicktale"
                        salesforce = [ordered]@{
                            campaign = $false
                            notes = $false
                        }
                        capsule = [ordered]@{
                            notes = $false
                        }
                    }
                    content_type = "template"
                }
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
        'Update-MailChimpCampaign' = @{
            '3.0' = @{
                Description = 'Update MailChimp campaign'
                URI         = 'campaigns/{id}/content'
                Method      = 'Put'
                Body        = [ordered]@{
                    plain_text = "plainText"
                    html = "html"
                    url = "url"
                    template = [ordered]@{
                        id = 0
                        sections = @{}
                    }
                    archive = [ordered]@{
                        archive_content = "archiveContent"
                        archive_type = "archiveType" # e.g. zip, tar.gz
                    }
                }
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
        'Get-MailChimpCampaignContent'    = @{
            '3.0' = @{
                Description = 'Get content of a MailChimp campaign'
                URI         = 'campaigns/{id}/content'
                Method      = 'Get'
                Body        = ''
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
        'Get-MailChimpList'    = @{
            '3.0' = @{
                Description = 'Get a list of MailChimp audience'
                URI         = 'lists/{id}'
                Method      = 'Get'
                Body        = ''
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
        'Get-MailChimpCampaign'    = @{
            '3.0' = @{
                Description = 'Get a list of MailChimp campaigns'
                URI         = 'campaigns/{id}'
                Method      = 'Get'
                Body        = ''
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
        'Send-MailChimpCampaign'    = @{
            '3.0' = @{
                Description = 'Send a MailChimp campaign'
                URI         = 'campaigns/{id}/actions/send'
                Method      = 'Post'
                Body        = ''
                Query       = ''
                Result      = ''
                Filter      = ''
                Success     = '200'
            }
        }
    }

    # TODO: APIVersion adding
    $key = '3.0'

    Write-Verbose -Message "Selected $key API Data for $endpoint"
    # Add the function name to resolve issue
    $api.$endpoint.$key.Add('Function', $endpoint)
    return $api.$endpoint.$key
}

Function Test-MailChimpApi()
{
    Write-Verbose -Message 'Testing the MailChimp API connection'
    if (-not $global:MailChimpConnection.header)
    {
        Write-Warning -Message 'Please connect to the MailChimp API before running this command.'
        throw 'A single connection with Test-MailChimpApi is required.'
    }
    Write-Verbose -Message 'Found a valid MailChimp API connection'
    $script:Header = $global:MailChimpConnection.header
}

function New-URIString($server, $endpoint, $id) {
    <#
      .SYNOPSIS
      Builds a valid URI
  
      .DESCRIPTION
      Builds a valid URI based off of the constructs defined in the Get-MailChimpAPIData resources for the cmdlet.
      Inserts any object IDs into the URI if {id} is specified within the constructs.
  
      .PARAMETER server
      The server endpoint name
      
      .PARAMETER endpoint
      The endpoint path
      
      .PARAMETER id
      An id value to be planted into the path or optionally at the end of the URI to retrieve a single object
    #>
  
    # Validation of id param
    if ($id -match '^@\{') {
      Write-Error -Message "Please validate ID input, please only input the ID parameter the object: '$id'" -ErrorAction Stop
    } elseif ($id.Length -gt 200) {
      Write-Error -Message "Please validate ID input, invalid ID provided: '$id'" -ErrorAction Stop
    }
  
    Write-Verbose -Message 'Build the URI'
    # If we find {id} in the path, replace it with the $id value  
    if ($endpoint.Contains('{id}')) {
      $uri = ('https://' + $server + $endpoint) -replace '{id}', $id
    }
    # Otherwise, only add the $id value at the end if it exists (for single object retrieval)
    else {
      $uri = 'https://' + $server + $endpoint
      if ($id) {
        $uri += "/$id"
      }
    }
    Write-Verbose -Message "URI = $uri"
      
    return $uri
  }

function Submit-Request
{
    <#
        .SYNOPSIS
        Sends data to an endpoint and formats the response
        .DESCRIPTION
        This is function is used by nearly every cmdlet in order to form and send the request off to an API endpoint.
        The results are then formated for further use and returned.
        .PARAMETER uri
        The endpoint's URI

        .PARAMETER header
        The header containing authentication details

        .PARAMETER method
        The action (method) to perform on the endpoint
        .PARAMETER body
        Any optional body data being submitted to the endpoint
    #>


    [cmdletbinding(SupportsShouldProcess = $true)]
    param(
        $uri,
        $header,
        $method = $($resources.Method),
        $body
    )

    if ($PSCmdlet.ShouldProcess($id, $resources.Description))
    {
        try
        {
            Write-Verbose -Message 'Submitting the request'
            $result = (Invoke-MailChimpRequest -Uri $uri -Headers $header -Method $method -Body $body)
        }
        catch
        {
            Throw $_
        }

        return $result

    }
}

Function Invoke-MailChimpRequest
{
    [cmdletbinding(SupportsShouldProcess)]
    param(
        $Uri,
        $Headers,
        $Method,
        $Body
    )

    $result = Invoke-RestMethod @PSBoundParameters

    Write-Verbose -Message "Received HTTP Status $($result.StatusCode)"

    return $result

}

Function New-BodyString($bodykeys, $parameters)
{
    <#
      .SYNOPSIS
      Function to create the body payload for an API request
      .DESCRIPTION
      This function compares the defined body parameters within Get-MailChimpAPIData with any parameters set within the invocation process.
      If matches are found, a properly formatted and valid body payload is created and returned.
      .PARAMETER bodykeys
      All of the body options available to the endpoint

      .PARAMETER parameters
      All of the parameter options available within the parent function
    #>

    # If sending a GET request, no body is needed
    if ($resources.Method -eq 'Get')
    {
        return $null
    }

    # Look at the list of parameters that were set by the invocation process
    # This is how we know which params were actually set by the call, versus defaulting to some zero, null, or false value
    # We can also add any custom variables here, such as SLAID which is populated after the invocation resolves the name
    if ($slaid -and $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('SLAID'))
    {
        $PSCmdlet.MyInvocation.BoundParameters.SLAID = $slaid
    }
    elseif ($slaid)
    {
        $PSCmdlet.MyInvocation.BoundParameters.Add('SLAID', $slaid)
    }

    # Now that custom params are added, let's inventory all invoked params
    $setParameters = $pscmdlet.MyInvocation.BoundParameters
    Write-Verbose -Message "List of set parameters: $($setParameters.GetEnumerator())"

    Write-Verbose -Message 'Build the body parameters'
    $bodystring = @{ }
    # Walk through all of the available body options presented by the endpoint
    # Note: Keys are used to search in case the value changes in the future across different API versions
    foreach ($body in $bodykeys)
    {
        Write-Verbose "Adding $body..."
        # Array Object
        if ($resources.Body.$body.GetType().BaseType.Name -eq 'Array')
        {
            $bodyarray = $resources.Body.$body.Keys
            $arraystring = @{ }
            foreach ($arrayitem in $bodyarray)
            {
                # Walk through all of the parameters defined in the function
                # Both the parameter name and parameter alias are used to match against a body option
                # It is suggested to make the parameter name "human friendly" and set an alias corresponding to the body option name
                foreach ($param in $parameters)
                {
                    # If the parameter name or alias matches the body option name, build a body string

                    if ($param.Name -eq $arrayitem -or $param.Aliases -eq $arrayitem)
                    {
                        # Switch variable types
                        if ((Get-Variable -Name $param.Name).Value.GetType().Name -eq 'SwitchParameter')
                        {
                            $arraystring.Add($arrayitem, (Get-Variable -Name $param.Name).Value.IsPresent)
                        }
                        # All other variable types
                        elseif ($null -ne (Get-Variable -Name $param.Name).Value)
                        {
                            $arraystring.Add($arrayitem, (Get-Variable -Name $param.Name).Value)
                        }
                    }
                }
            }
            $bodystring.Add($body, @($arraystring))
        }

        # Non-Array Object
        else
        {
            # Walk through all of the parameters defined in the function
            # Both the parameter name and parameter alias are used to match against a body option
            # It is suggested to make the parameter name "human friendly" and set an alias corresponding to the body option name
            foreach ($param in $parameters)
            {
                # If the parameter name or alias matches the body option name, build a body string
                if (($param.Name -eq $body -or $param.Aliases -eq $body) -and $setParameters.ContainsKey($param.Name))
                {
                    # Switch variable types
                    if ((Get-Variable -Name $param.Name).Value.GetType().Name -eq 'SwitchParameter')
                    {
                        $bodystring.Add($body, (Get-Variable -Name $param.Name).Value.IsPresent)
                    }
                    # All other variable types
                    elseif ($null -ne (Get-Variable -Name $param.Name).Value -and (Get-Variable -Name $param.Name).Value.Length -gt 0)
                    {
                        # These variables will be cast to upper or lower, depending on what the API endpoint expects
                        $ToUpperVariable = @('Protocol')
                        $ToLowerVariable = @('')

                        if ($body -in $ToUpperVariable)
                        {
                            $bodystring.Add($body, (Get-Variable -Name $param.Name).Value.ToUpper())
                        }
                        elseif ($body -in $ToLowerVariable)
                        {
                            $bodystring.Add($body, (Get-Variable -Name $param.Name).Value.ToLower())
                        }
                        else
                        {
                            $bodystring.Add($body, (Get-Variable -Name $param.Name).Value)
                        }
                    }
                }
            }
        }
    }

    # Store the results into a JSON string
    if (0 -ne $bodystring.count)
    {
        $bodystring = ConvertTo-Json -InputObject $bodystring
        Write-Verbose -Message "Body = $bodystring"
    }
    else
    {
        Write-Verbose -Message 'No body for this request'
    }
    return $bodystring
}
Function Test-QueryParam($querykeys, $parameters, $uri)
{
    Write-Verbose -Message "Build the query parameters for $(if ($querykeys) { $querykeys -join ', ' }else { '<null>' })"
    $querystring = @()
    # Walk through all of the available query options presented by the endpoint
    # Note: Keys are used to search in case the value changes in the future across different API versions
    foreach ($query in $querykeys)
    {
        # Walk through all of the parameters defined in the function
        # Both the parameter name and parameter alias are used to match against a query option
        # It is suggested to make the parameter name "human friendly" and set an alias corresponding to the query option name
        foreach ($param in $parameters)
        {
            # If the parameter name matches the query option name, build a query string
            if ($param.Name -eq $query)
            {
                $querystring += Test-QueryObject -object (Get-Variable -Name $param.Name).Value -location $resources.Query[$param.Name] -params $querystring
            }
            # If the parameter alias matches the query option name, build a query string
            elseif ($param.Aliases -eq $query)
            {
                $querystring += Test-QueryObject -object (Get-Variable -Name $param.Name).Value -location $resources.Query[$param.Aliases] -params $querystring
            }
        }
    }
    # After all query options are exhausted, build a new URI with all defined query options

    $uri = New-QueryString -query $querystring -uri $uri
    Write-Verbose -Message "URI = $uri"

    return $uri
}
Function New-QueryString($query, $uri, $nolimit)
{
    # TODO: It seems like there's a more elegant way to do this logic, but this code is stable and functional.
    foreach ($_ in $query)
    {
        # The query begins with a "?" character, which is appended to the $uri after determining that at least one $params was collected
        if ($_ -eq $query[0])
        {
            $uri += '/' + $_
            # $uri += '?' + $_ Old way
        }
        # Subsequent queries are separated by a "&" character
        else
        {
            $uri += '&' + $_
        }
    }
    return $uri
}

Function Test-QueryObject($object, $location, $query)
{
    <#
      .SYNOPSIS
      Builds a query string for an endpoint
      .DESCRIPTION
      The Test-QueryObject function is used to build a custom query string for supported endpoints
      .PARAMETER object
      The parent function's variable holding the user generated query data

        .PARAMETER location
        The key/value pair that contains the correct query name value

        .PARAMETER params
        An array of query values that are added based on which $objects have been passed by the user
        #>

    Write-Debug -Message ($PSBoundParameters | Out-String)

    if ((-not [string]::IsNullOrWhiteSpace($object)) -and ($location))
    {
        return "$object"
        # return "$location=$object" Old way
    }
}

#endregin Private functions

#region Public functions
Function Connect-MailChimpApi
{
    <#
    .SYNOPSIS
        Connects to the MailChimp API using the provided API key and base URL.

    .DESCRIPTION
        The Connect-MailChimpApi function establishes a connection to the MailChimp API by setting up the necessary headers and base URL for subsequent API requests. This function is essential for authenticating and interacting with the MailChimp service.

    .PARAMETER ApiKey
        The API key used to authenticate with the MailChimp API.

    .EXAMPLE
        $apiKey = "your-api-key"
        Connect-MailChimpApi -ApiKey $apiKey

    .NOTES
        Ensure that you replace "your-api-key" with your actual MailChimp API key and "usX" with the appropriate data center for your account.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    Begin
    {
        try
        {
            if ([Net.ServicePointManager]::SecurityProtocol -notlike '*Tls12*')
            {
                Write-Verbose -Message 'Adding TLS 1.2'
                [Net.ServicePointManager]::SecurityProtocol = ([Net.ServicePointManager]::SecurityProtocol).tostring() + ', Tls12'
            }
        }
        catch
        {
            Write-Verbose -Message $_
            Write-Verbose -Message $_.Exception.InnerException.Message
        }

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"

        # API key contains the datacenter information
        $resources.URI = $resources.URI.Replace('<dc>', ($ApiKey -split '-')[-1])

        # Capture against the global variable
        $serverUri = $resources.URI.Replace('<dc>', ($ApiKey -split '-')[-1])

    }

    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        $newUri = $uri + "?fields=account_id"

        # Standard Basic Auth Base64 encoded header with username:password
        $Head = @{ 'Authorization' = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("anystring:" + $ApiKey)) }
        $Head += @{ 'Content-type' = 'application/json' }
        $content = Submit-Request -uri $newUri -header $head -method $($resources.Method)
        Write-Verbose -Message 'Storing all connection details into $global:MailChimpConnection'
        $global:MailChimpConnection = @{
            server   = $serverUri
            header   = $head
            accountId     = $content.account_id
            time     = (Get-Date)
            authType = 'anystring:'
        }
    }
}

function New-MailChimpCampaign
{
    <#
    .SYNOPSIS
        Creates a new MailChimp campaign.

    .DESCRIPTION
        The New-MailChimpCampaign function creates a new campaign in MailChimp using the provided parameters. This function allows you to specify various settings and tracking options for the campaign.

    .PARAMETER Type
        The type of campaign. Default is "regular".

    .PARAMETER ListId
        The ID of the list to send the campaign to.

    .PARAMETER SubjectLine
        The subject line for the campaign.

    .PARAMETER PreviewText
        The preview text for the campaign.

    .PARAMETER Title
        The title of the campaign.

    .PARAMETER FromName
        The name of the sender.

    .PARAMETER ReplyTo
        The reply-to email address.

    .PARAMETER UseConversation
        Indicates whether to use conversation tracking. Default is $false.

    .PARAMETER ToName
        The recipient's name.

    .PARAMETER FolderId
        The ID of the folder to save the campaign in.

    .PARAMETER Authenticate
        Indicates whether to authenticate the campaign. Default is $false.

    .PARAMETER AutoFooter
        Indicates whether to automatically add a footer. Default is $false.

    .PARAMETER InlineCss
        Indicates whether to inline CSS. Default is $false.

    .PARAMETER AutoTweet
        Indicates whether to automatically tweet the campaign. Default is $false.

    .PARAMETER FbComments
        Indicates whether to enable Facebook comments. Default is $false.

    .PARAMETER TemplateId
        The ID of the template to use. Default is 0.

    .PARAMETER Opens
        Indicates whether to track opens. Default is $false.

    .PARAMETER HtmlClicks
        Indicates whether to track HTML clicks. Default is $false.

    .PARAMETER TextClicks
        Indicates whether to track text clicks. Default is $false.

    .PARAMETER GoalTracking
        Indicates whether to enable goal tracking. Default is $false.

    .PARAMETER Ecomm360
        Indicates whether to enable eCommerce tracking. Default is $false.

    .PARAMETER GoogleAnalytics
        The Google Analytics tracking ID.

    .PARAMETER Clicktale
        The Clicktale tracking ID.

    .PARAMETER SalesforceCampaign
        Indicates whether to enable Salesforce campaign tracking. Default is $false.

    .PARAMETER SalesforceNotes
        Indicates whether to enable Salesforce notes tracking. Default is $false.

    .PARAMETER CapsuleNotes
        Indicates whether to enable Capsule notes tracking. Default is $false.

    .PARAMETER ContentType
        The content type of the campaign. Default is "template".

    .PARAMETER Server
        The MailChimp server URL. Default is the server URL from the global MailChimp connection.

    .EXAMPLE
        New-MailChimpCampaign -Type "regular" -ListId "12345" -SubjectLine "New Campaign" -FromName "My Company" -ReplyTo "info@mycompany.com"

    .NOTES
        Ensure that you have connected to the MailChimp API using Connect-MailChimpApi before calling this function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Type = "regular",

        [Parameter(Mandatory = $false)]
        [string] $ListId = "",

        [Parameter(Mandatory = $false)]
        [string] $SubjectLine = "",

        [Parameter(Mandatory = $false)]
        [string] $PreviewText = "",

        [Parameter(Mandatory = $false)]
        [string] $Title = "",

        [Parameter(Mandatory = $false)]
        [string] $FromName = "s",

        [Parameter(Mandatory = $false)]
        [string] $ReplyTo = "",
 
        [Parameter(Mandatory = $false)]
        [bool] $UseConversation = $false,

        [Parameter(Mandatory = $false)]
        [string] $ToName = "",

        [Parameter(Mandatory = $false)]
        [string] $FolderId = "",

        [Parameter(Mandatory = $false)]
        [bool] $Authenticate = $false,

        [Parameter(Mandatory = $false)]
        [bool] $AutoFooter = $false,

        [Parameter(Mandatory = $false)]
        [bool] $InlineCss = $false,

        [Parameter(Mandatory = $false)]
        [bool] $AutoTweet = $false,

        [Parameter(Mandatory = $false)]
        [bool] $FbComments = $false,

        [Parameter(Mandatory = $false)]
        [Int] $TemplateId = 0,

        [Parameter(Mandatory = $false)]
        [bool] $Opens = $false,

        [Parameter(Mandatory = $false)]
        [bool] $HtmlClicks = $false,

        [Parameter(Mandatory = $false)]
        [bool] $TextClicks = $false,

        [Parameter(Mandatory = $false)]
        [bool] $GoalTracking = $false,

        [Parameter(Mandatory = $false)]
        [bool] $Ecomm360 = $false,
 
        [Parameter(Mandatory = $false)]
        [string] $GoogleAnalytics = "",

        [Parameter(Mandatory = $false)]
        [string] $Clicktale = "",

        [Parameter(Mandatory = $false)]
        [bool] $SalesforceCampaign = $false,

        [Parameter(Mandatory = $false)]
        [bool] $SalesforceNotes = $false,

        [Parameter(Mandatory = $false)]
        [bool] $CapsuleNotes = $false,

        [Parameter(Mandatory = $false)]
        [string] $ContentType = "template",

        [Parameter(Mandatory = $false)]
        [string]$Server = $global:MailChimpConnection.server
    )

    Begin
    {
        Test-MailChimpApi

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        # Retrieve all of the URI, method, body, query, result, filter, and success details for the API endpoint
        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"
    }
    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        # We create the full body first as it is quite sensitive
        Write-Verbose -Message "Building body"
        $body = [ordered]@{
            type = $Type
            recipients = [ordered]@{
                list_id = $ListId
            }
            settings = [ordered]@{
                subject_line = $SubjectLine
                preview_text = $PreviewText
                title = $Title
                from_name = $FromName
                reply_to = $ReplyTo
                use_conversation = $UseConversation
                to_name = $ToName
                folder_id = $FolderId
                authenticate = $Authenticate
                auto_footer = $AutoFooter
                inline_css = $InlineCss
                auto_tweet = $AutoTweet
                fb_comments = $FbComments
                template_id = $TemplateId
            }
            tracking = [ordered]@{
                opens = $Opens
                html_clicks = $HtmlClicks
                text_clicks = $TextClicks
                goal_tracking = $GoalTracking
                ecomm360 = $Ecomm360
                google_analytics = $GoogleAnalytics
                clicktale = $Clicktale
                salesforce = [ordered]@{
                    campaign = $SalesforceCampaign
                    notes = $SalesforceNotes
                }
                capsule = [ordered]@{
                    notes = $CapsuleNotes
                }
            }
            content_type = $ContentType
        }

        $body = ConvertTo-Json $body -Depth 10

        Write-Verbose -Message "Body = $body"

        $result = Submit-Request -uri $uri -header $Header -method $($resources.Method) -body $body
        return $result
    } 
}

function Update-MailChimpCampaign
{
    <#
    .SYNOPSIS
        Updates a MailChimp campaign with the specified parameters.

    .DESCRIPTION
        The Update-MailChimpCampaign function updates a MailChimp campaign using the provided parameters. 
        It constructs the API request and submits it to the MailChimp server.

    .PARAMETER Id
        The unique identifier for the MailChimp campaign. This parameter is mandatory.

    .PARAMETER PlainText
        The plain text content of the campaign. This parameter is optional.

    .PARAMETER Html
        The HTML content of the campaign. This parameter is optional.

    .PARAMETER Url
        The URL content of the campaign. This parameter is optional.

    .PARAMETER TemplateId
        The template ID to be used for the campaign. This parameter is optional.

    .PARAMETER Sections
        A hashtable containing the sections of the campaign. This parameter is optional.

    .PARAMETER ArchiveContent
        The archive content of the campaign. This parameter is optional.

    .PARAMETER ArchiveType
        The type of archive for the campaign. Valid values are 'zip' and 'tar.gz'. This parameter is optional.

    .PARAMETER Server
        The MailChimp server to connect to. Defaults to the global MailChimp connection server.

    .EXAMPLE
        Update-MailChimpCampaign -Id "12345" -PlainText "Sample text" -Html "<h1>Sample HTML</h1>"

    .NOTES
        This function requires the MailChimp API to be accessible and the necessary permissions to update campaigns.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias('CampaignId')]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [string] $PlainText,

        [Parameter(Mandatory = $false)]
        [string] $Html,

        [Parameter(Mandatory = $false)]
        [string] $Url,

        [Parameter(Mandatory = $false)]
        [int] $TemplateId,

        [Parameter(Mandatory = $false)]
        [hashtable] $Sections,

        [Parameter(Mandatory = $false)]
        [string] $ArchiveContent,

        [Parameter(Mandatory = $false)]
        [ValidateSet('zip', 'tar.gz')]
        [string] $ArchiveType,

        [Parameter(Mandatory = $false)]
        [string] $Server = $global:MailChimpConnection.server
    )

    Begin
    {
        Test-MailChimpApi

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        # Retrieve all of the URI, method, body, query, result, filter, and success details for the API endpoint
        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"
    }
    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        Write-Verbose -Message "Building body"
        $body = [ordered]@{
            plain_text = $PlainText
            html = $Html
            url = $Url
        }

        # TODO: add function to add bound parameters to hash
        # if ($PSBoundParameters.ContainsKey('TemplateId') -and $null -ne $Sections) {
        #     $body.Add('template', [ordered]@{
        #         id = $TemplateId
        #     })
        # }

        # if ($PSBoundParameters.ContainsKey('Sections') -and $null -ne $Sections) {
        #     # template = [ordered]@{
        #     #     id = $TemplateId
        #     #     sections = $Sections
        #     # }
        #     # archive = [ordered]@{
        #     #     archive_content = $ArchiveContent
        #     #     archive_type = $ArchiveType
        #     # }
        # }

        $body = ConvertTo-Json $body -Depth 10

        Write-Verbose -Message "Body = $body"

        $result = Submit-Request -uri $uri -header $Header -method $($resources.Method) -body $body
        return $result
    } 
}

function Get-MailChimpCampaignContent
{
    <#
    .SYNOPSIS
        Retrieves the content of a specified MailChimp campaign.

    .DESCRIPTION
        The Get-MailChimpCampaignContent function fetches the content of a MailChimp campaign using the campaign ID. 
        It retrieves both the HTML and plain text content of the campaign.

    .PARAMETER Id
        The unique identifier for the MailChimp campaign. This parameter is mandatory.

    .PARAMETER Server
        The MailChimp server to connect to. Defaults to the global MailChimp connection server.

    .EXAMPLE
        Get-MailChimpCampaignContent -Id "12345"

        This example retrieves the content of the MailChimp campaign with the ID "12345".

    .NOTES
        This function requires the MailChimp API to be accessible and the necessary permissions to retrieve campaign content.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias('CampaignId')]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [string] $Server = $global:MailChimpConnection.server
    )

    Begin
    {
        Test-MailChimpApi

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        # Retrieve all of the URI, method, body, query, result, filter, and success details for the API endpoint
        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"
    }
    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        $result = Submit-Request -uri $uri -header $Header -method $($resources.Method)
        return $result
    } 
}

function Get-MailChimpList
{
    <#
    .SYNOPSIS
        Retrieves the details of a specified MailChimp list.

    .DESCRIPTION
        The Get-MailChimpList function fetches the details of a MailChimp list using the list ID. 
        It retrieves various information about the list, including its members and settings.

    .PARAMETER Id
        The unique identifier for the MailChimp list. This parameter is optional.

    .PARAMETER Server
        The MailChimp server to connect to. Defaults to the global MailChimp connection server.

    .EXAMPLE
        Get-MailChimpList -Id "12345"

        This example retrieves the details of the MailChimp list with the ID "12345".

    .EXAMPLE
        Get-MailChimpList

        This example retrieves the details of all MailChimp lists.
    .NOTES
        This function requires the MailChimp API to be accessible and the necessary permissions to retrieve list details.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Alias('AudienceId')]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [string] $Server = $global:MailChimpConnection.server
    )

    Begin
    {
        Test-MailChimpApi

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        # Retrieve all of the URI, method, body, query, result, filter, and success details for the API endpoint
        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"
    }
    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        $result = Submit-Request -uri $uri -header $Header -method $($resources.Method)
        return $result
    } 
}

function Get-MailChimpCampaign
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Alias('CampaignId')]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [string] $Server = $global:MailChimpConnection.server
    )

    Begin
    {
        Test-MailChimpApi

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        # Retrieve all of the URI, method, body, query, result, filter, and success details for the API endpoint
        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"
    }
    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        $result = Submit-Request -uri $uri -header $Header -method $($resources.Method)
        return $result
    } 
}

function Send-MailChimpCampaign
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Alias('CampaignId')]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [string] $Server = $global:MailChimpConnection.server
    )

    Begin
    {
        Test-MailChimpApi

        # API data references the name of the function
        # For convenience, that name is saved here to $function
        $function = $MyInvocation.MyCommand.Name

        # Retrieve all of the URI, method, body, query, result, filter, and success details for the API endpoint
        Write-Verbose -Message "Gather API Data for $function"
        $resources = Get-MailChimpApiData -endpoint $function
        Write-Verbose -Message "Load API data for $($resources.Function)"
        Write-Verbose -Message "Description: $($resources.Description)"
    }
    Process
    {
        $uri = New-URIString -server $Server -endpoint ($resources.URI) -id $id
        $uri = Test-QueryParam -querykeys ($resources.Query.Keys) -parameters ((Get-Command $function).Parameters.Values) -uri $uri

        $result = Submit-Request -uri $uri -header $Header -method $($resources.Method)
        return $result
    } 
}

#endregion Public functions

#endregion Functions