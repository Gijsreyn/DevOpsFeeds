# Configuration -------------------------------
$template_id = 9614495
$template_html = '<p>Ayo whatup? THIS IS THE SAMPLE CONTENT BODY OF MY EMAIL MESSAGE.</p>'
$api_key = ""; 
$list_id = "59c1aeea86";
$subject = "Hello, You've successfully subscribed to our Newsletter!";
$reply_to = "gijsreijn@Hotmail.com"; 
$from_name = "Gijs";
$base_url = "https://us14.api.mailchimp.com/3.0"  # Replace <dc> with your MailChimp data center (e.g., us19)

# MailChimp API headers for authorization
$headers = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("anystring:" + $api_key))
    ContentType   = "application/json"
}

# Start create email campaign ->

# Create or Post new Campaign
$campaignBody = @{
    type       = 'regular'
    recipients = @{
        list_id = $list_id
    }
    settings   = @{
        subject_line = $subject
        reply_to     = $reply_to
        from_name    = $from_name
    }
}

$campaignResponse = Invoke-RestMethod -Uri "$base_url/campaigns" -Method Post -Headers $headers -Body ($campaignBody | ConvertTo-Json)
$campaign_id = $campaignResponse.id

# Update Template content
$templateBody = @{
    template = @{
        id       = [int]$template_id
        sections = @{
            html = $template_html
        }
    }
}

$templateResponse = Invoke-RestMethod -Uri "$base_url/campaigns/$campaign_id/content" -Method Put -Headers $headers -Body ($templateBody | ConvertTo-Json)

# Send Campaign
$sendResponse = Invoke-RestMethod -Uri "$base_url/campaigns/$campaign_id/actions/send" -Method Post -Headers $headers

# Output results
$sendResponse

