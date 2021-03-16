<#
.Synopsis
    Get Azure AD groups deployed in the Azure AD tenant
.Description
    This function gets the Azure AD groups from Azure AD using the Microsoft Graph API.
    The following Microsoft Graph API permissions are required for the service principal used for authentication:
        group.ReadWrite.ConditionalAccess
        group.Read.All
        Directory.Read.All
        Agreement.Read.All
        Application.Read.All
.PARAMETER ClientID
    Client ID for the Azure AD service principal with Azure AD group Graph permissions
.PARAMETER ClientSecret
    Client secret for the Azure AD service principal with Azure AD group Graph permissions
.PARAMETER TenantName
    The initial domain (onmicrosoft.com) of the tenant
.PARAMETER AccessToken
    The access token, obtained from executing Get-WTGraphAccessToken
.PARAMETER ExcludePreviewFeatures
    Specify whether to exclude features in preview, a production API version will then be used instead
.INPUTS
    JSON file with all Azure AD groups
.OUTPUTS
    None
.NOTES

.Example
    $Parameters = @{
                ClientID = ""
                ClientSecret = ""
                TenantDomain = ""
    }
    Get-WTAzureADGroup @Parameters
    Get-WTAzureADGroup -AccessToken $AccessToken
#>

function Export-WTGroupTemplate {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The path where the JSON file will be created"
        )]
        [string]$Path,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The file path where the JSON file will be created"
        )]
        [string]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to include optional properties"
        )]
        [switch]$IncludeOptionalProperties
    )
    Begin {
        try {
            
            # Variables
            $TemplateProperties = [ordered]@{
                displayName     = $null
                mailEnabled     = $null
                mailNickname    = $null
                securityEnabled = $null
            }
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # If, in addition to required properties, optional properties should be included
            if ($IncludeOptionalProperties) {
                $TemplateProperties.Add("description", $null)
                $TemplateProperties.Add("owners", $null)
                $TemplateProperties.Add("members", $null)
                $TemplateProperties.Add("visibility", $null)
            }

            # Export to JSON
            if ($FilePath) {
                $TemplateProperties | ConvertTo-Json -Depth 10 `
                | Out-File -Force -FilePath $FilePath
            }
            else {
                $TemplateProperties | ConvertTo-Json -Depth 10 `
                | Out-File -Force -FilePath "$Path\GroupTemplate.json"
            }
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    End {
        
    }
}