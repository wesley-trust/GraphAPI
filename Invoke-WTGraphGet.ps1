<#
.Synopsis
    Get Conditional Access policies deployed in the Azure AD tenant
.Description
    This function gets the Conditional Access policies from Azure AD using the Microsoft Graph API.
    The following Microsoft Graph API permissions are required for the service principal used for authentication:
        Query.ReadWrite.ConditionalAccess
        Query.Read.All
        Directory.Read.All
        Agreement.Read.All
        Application.Read.All
.PARAMETER ClientID
    Client ID for the Azure AD service principal with Conditional Access Graph permissions
.PARAMETER ClientSecret
    Client secret for the Azure AD service principal with Conditional Access Graph permissions
.PARAMETER TenantName
    The initial domain (onmicrosoft.com) of the tenant
.PARAMETER AccessToken
    The access token, obtained from executing Get-WTGraphAccessToken
.PARAMETER ExcludePreviewFeatures
    Specify whether to exclude features in preview, a production API version will then be used instead
.PARAMETER ExcludeTagEvaluation
    Specify whether to exclude features in preview, a production API version will then be used instead
.INPUTS
    JSON file with all Conditional Access policies
.OUTPUTS
    None
.NOTES

.Example
    $Parameters = @{
                ClientID = ""
                ClientSecret = ""
                TenantDomain = ""
    }
    Get-CAQuery @Parameters
    $AccessToken | Get-CAQuery
#>

function Invoke-WTGraphGet {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Conditional Access Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Conditional Access Graph permissions"
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
            HelpMessage = "The specific record ids to be returned"
        )]
        [Alias("id")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The uniform resource indicator"
        )]
        [string]$Uri,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The optional tags that could be evaluated in the response"
        )]
        [string[]]$Tags,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The activity being performed"
        )]
        [string]$Activity
    )
    Begin {
        try {
            # Function definitions
            $FunctionLocation = "$ENV:USERPROFILE\GitHub\Scripts\Functions"
            $Functions = @(
                "$FunctionLocation\GraphAPI\Get-WTGraphAccessToken.ps1",
                "$FunctionLocation\GraphAPI\Invoke-WTGraphQuery.ps1"
                "$FunctionLocation\Toolkit\Invoke-WTPropertyTagging.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Method = "Get"
            $Counter = 1
            $PropertyToTag = "DisplayName"
            
            # Output current activity
            Write-Host $Activity
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {
            if ($AccessToken) {

                # Build parameters
                $Parameters = @{
                    Method = $Method
                }

                # Change the API version if features in preview are to be excluded
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                # If specific policies are specified, get each, otherwise, get all policies
                if ($IDs) {
                    $QueryResponse = foreach ($ID in $IDs) {
                        
                        # Output progress
                        if ($IDs.count -gt 1) {
                            Write-Host "Processing Query $Counter of $($IDs.count) with ID: $ID"
                                                
                            # Create progress bar
                            $PercentComplete = (($counter / $IDs.count) * 100)
                            Write-Progress -Activity $Activity `
                                -PercentComplete $PercentComplete `
                                -CurrentOperation $ID
                        }
                        else {
                            Write-Host "Processing Query $Counter with ID: $ID"
                        }

                        # Increment counter
                        $counter++

                        # Get Query
                        $AccessToken | Invoke-WTGraphQuery `
                            @Parameters `
                            -Uri $Uri/$ID
                    }
                }
                else {
                    $QueryResponse = $AccessToken | Invoke-WTGraphQuery `
                        @Parameters `
                        -Uri $Uri
                }

                # If there is a response, and tags are defined, evaluate the query response for tags, else return without tagging
                if ($QueryResponse) {
                    if ($Tags) {
                        Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $QueryResponse -PropertyToTag $PropertyToTag
                    }
                    else {
                        $QueryResponse
                    }
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
