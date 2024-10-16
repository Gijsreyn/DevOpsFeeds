# ![FeedLogo] DevOpsFeeds

![Newsletter]

The DevOpsFeeds repository is developed to send newsletter(s). Information is collected from open-source GitHub projects based on category. This information is transformed to HTML using PowerShell. When the information is transformed, the MailChimp API is invoked to start the campaign.

The following newsletters are configured and sent:

- Pull Request Newsletter

## Features

- Easy to setup campaign content
- Support dynamic feed data
- Integration with MailChimp templates and sections
- Azure DevOps pipeline to send mail

## Installation

The repository published a PowerShell module named `MailChimp`. You can use the following command to install the module from the PSGallery:

```powershell
Install-PSResource -Name MailChimp -Repository PSGallery
```

## Usage

If you want to play with the PowerShell module, you can check out the following code samples:

```powershell
# Retrieve campaign content
$campaigns = Get-MailChimpCampaign # get all campaigns on MailChimp
Get-MailChimpCampaignContent -Id $campaigns[0].Id

# Update campaign content
Update-MailChimpCampaign -Id "your-campaign-id" -Html "<h1>Sample HTML</h1>"
```

## Pipeline setup

Each Sunday at 6 o'clock, a scheduled trigger runs a pipeline. The steps the pipeline performs:

1. Bootstrap the environment on ubuntu-latest agent
2. Connects to MailChimp API
3. Generates MailChimp newsletter as HTML
4. Create campaign in MailChimp with results from 1 week
5. Send out campaign to audience

Both MailChimp API and GitHub are authenticated using API keys. For more information, check out [MailChimp API reference](https://mailchimp.com/developer/marketing/) or [GitHub](https://docs.github.com/en/rest) documentation.

## Contributing

We welcome contributions to the repository. The process to include a new feed is straightforward. If you find a feed you want to add, check out the [data files](./res/data/). You can fork the repository, add your feed, and push the changes.

If you have any other suggestions, bug reports, or feature requests, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

<!-- References -->
[FeedLogo]: .images/feed-48.png
[Newsletter]: .images/image-newsletter.png