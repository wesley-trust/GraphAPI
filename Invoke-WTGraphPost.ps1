<#
.Synopsis
    Create new Conditional Access policies in the Azure AD tenant
.Description
    This function creates the Conditional Access policies in Azure AD using the Microsoft Graph API.
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
.PARAMETER ConditionalAccessPolicies
    Specify the Conditional Access policies to create
.INPUTS
    None
.OUTPUTS
    None
.NOTES

.Example
    $Parameters = @{
                ClientID = ""
                ClientSecret = ""
                TenantDomain = ""
    }
    New-CAQuery @Parameters -CondionalAccessPolicies $CondionalAccessPolicies
    $CondionalAccessPolicies | New-CAQuery -AccessToken $AccessToken
#>

function Invoke-WTGraphPost {
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
            HelpMessage = "The objects to be created"
        )]
        [pscustomobject]$InputObject,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The uniform resource indicator"
        )]
        [string]$Uri,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The activity being performed"
        )]
        [string]$Activity,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Properties that may exist that need to be removed prior to creation"
        )]
        [string[]]$CleanUpProperties
    )
    Begin {
        try {
            # Function definitions
            $FunctionLocation = "$ENV:USERPROFILE\GitHub\Scripts\Functions"
            $Functions = @(
                "$FunctionLocation\GraphAPI\Get-WTGraphAccessToken.ps1",
                "$FunctionLocation\GraphAPI\Invoke-WTGraphQuery.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Method = "Post"
            $Counter = 1
            
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
                    Uri    = $Uri
                }

                # Change the API version if features in preview are to be excluded
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # If there are policies to deploy, for each
                if ($InputObject) {
                    
                    foreach ($Object in $InputObject) {

                        # Remove properties that are not valid for when creating new objects
                        if ($CleanUpProperties) {
                            foreach ($Property in $CleanUpProperties) {
                                $Object.PSObject.Properties.Remove("$Property")
                            }
                        }
                        
                        # Update displayname variable prior to object conversion to JSON
                        $ObjectDisplayName = $Object.displayName

                        # Convert Query object to JSON
                        $Object = $Object | ConvertTo-Json -Depth 10

                        # Output progress
                        if ($InputObject.count -gt 1) {
                            Write-Host "Processing Query $Counter of $($InputObject.count) with Display Name: $ObjectDisplayName"
                        
                            # Create progress bar
                            $PercentComplete = (($counter / $InputObject.count) * 100)
                            Write-Progress -Activity $Activity `
                                -PercentComplete $PercentComplete `
                                -CurrentOperation $ObjectDisplayName
                        }
                        else {
                            Write-Host "Processing Query $Counter with Display Name: $ObjectDisplayName"
                            
                        }
                        
                        # Increment counter
                        $counter++

                        # Create record, with one second intervals to prevent throttling
                        Start-Sleep -Seconds 1
                        $AccessToken | Invoke-WTGraphQuery `
                            @Parameters `
                            -Body $Object
                        #| Out-Null
                    }
                }
                else {
                    $ErrorMessage = "There are no records to be created"
                    Write-Error $ErrorMessage
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
