function New-WTEMAppPolicy {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Endpoint Manager policy Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Endpoint Manager policy Graph permissions"
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "Specify the Endpoint Manager App Policies to create"
        )]
        [Alias("AppPolicy","PolicyDefinition","EMAppPolicies","EMAppPolicy")]
        [PSCustomObject]$AppPolicies,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager App policy type to create"
        )]
        [ValidateSet("Protection")]
        [string]$PolicyType = "Protection",
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the App Policy platform to target, only required when one is not specified in the config"
        )]
        [ValidateSet("Android", "iOS")]
        [string]$Platform
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphPost.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Creating Endpoint Manager App $PolicyType policies"
            $Uri = "deviceAppManagement/managedAppPolicies"
            $CleanUpProperties = (
                "id",
                "createdDateTime",
                "lastModifiedDateTime",
                "SideIndicator",
                "version",
                "SVC",
                "REF",
                "ENV"
            )
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
                
                # Variables based upon parameters
                if ($PolicyType -eq "Protection") {
                    if ($Platform -eq "Android") {
                        $Uri = "deviceAppManagement/androidManagedAppProtections"
                    }
                    elseif ($Platform -eq "iOS") {
                        $Uri = "deviceAppManagement/iosManagedAppProtections"
                    }
                }

                # Build Parameters
                $Parameters = @{
                    AccessToken       = $AccessToken
                    CleanUpProperties = $CleanUpProperties
                    Activity          = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                # If there are App Policies to deploy, for each
                if ($AppPolicies) {
                    
                    # Create App Policies
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $AppPolicies `
                        -Uri $Uri
                }
                else {
                    $ErrorMessage = "There are no Endpoint Manager App $PolicyType Policies to be created"
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
        try {
            
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
}