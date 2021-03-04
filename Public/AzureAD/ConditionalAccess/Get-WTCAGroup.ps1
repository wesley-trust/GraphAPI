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

function Get-WTCAGroup {
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
            ValueFromPipeLine = $true,
            HelpMessage = "The Conditional Access groups to get, this must contain valid id(s)"
        )]
        [Alias("id", "GroupID", "GroupIDs")]
        [string[]]$IDs
    )
    Begin {
        try {
            # Function definitions
            $FunctionLocation = "$ENV:USERPROFILE\GitHub\Scripts\Functions"
            $Functions = @(
                "$FunctionLocation\GraphAPI\Get-WTGraphAccessToken.ps1",
                "$FunctionLocation\Azure\AzureAD\Groups\Get-WTAzureADGroup.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Tag = "SVC"
            $Service = "CA"

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
                if ($IDs) {
                    $Parameters.Add("IDs", $IDs)
                }
                
                # Get Azure AD groups, and filter
                $ConditionalAccessGroups = Get-WTAzureADGroup @Parameters | Where-Object {$_.$Tag -eq $Service}
                
                # Return response if the filtered objects contain the specified service
                if ($ConditionalAccessGroups) {
                    $ConditionalAccessGroups
                }
                else {
                    $WarningMessage = "No Conditional Access groups exist in Azure AD, or with the specified IDs"
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
