<#
.Synopsis
    Get Azure AD groups deployed in the Azure AD tenant
.Description
    This function gets the Azure AD groups from Azure AD using the Microsoft Graph API.
    The following Microsoft Graph API permissions are required for the service principal used for authentication:
        Policy.ReadWrite.ConditionalAccess
        Policy.Read.All
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
.PARAMETER ExcludeTagEvaluation
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

function Remove-WTCAGroup {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Azure AD group Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Azure AD group Graph permissions"
        )]
        [string]$ClientSecret,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The initial domain (onmicrosoft.com) of the tenant"
        )]
        [string]$TenantDomain,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The access token, obtained from executing Get-WTGraphAccessToken"
        )]
        [string]$AccessToken,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Conditional Access groups to get, this must contain valid id(s)"
        )]
        [Alias("id", "GroupID", "GroupIDs")]
        [string[]]$IDs
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Get-WTCAGroup.ps1"
                "GraphAPI\Public\AzureAD\Groups\Remove-WTAzureADGroup.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # If there is no access token, obtain one
            if (!$AccessToken) {
                $AccessToken = Get-WTGraphAccessToken `
                    -ClientID $ClientID `
                    -ClientSecret $ClientSecret `
                    -TenantDomain $TenantDomain
            }
            if ($AccessToken) {
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                # Pass IDs to function, and return only Conditional Access groups
                if ($IDs){
                    $CAGroups = Get-WTCAGroup @Parameters -IDs $IDs
                }

                # Return response if the filtered objects contain the specified service
                if ($CAGroups) {
                    if ($CAGroups.id.count -lt $IDs.count) {
                        $WarningMessage = "There are groups marked for removal, that are not CA groups, these will be ignored and will not be removed"
                        Write-Warning $WarningMessage
                    }
                    Remove-WTAzureADGroup @Parameters -IDs $CAGroups.id
                }
                else {
                    $WarningMessage = "No Conditional Access groups to be removed in Azure AD"
                    Write-Warning $WarningMessage
                }
            }
            else {
                $ErrorMessage = "No access token specified, obtain an access token object from Get-WTGraphAccessToken"
                Write-Error $ErrorMessage
                throw $ErrorMessage
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
