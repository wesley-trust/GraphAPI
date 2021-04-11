function Remove-WTEMAppPolicyRelationship {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Azure AD relationship Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Azure AD relationship Graph permissions"
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
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Endpoint Manager App policies to remove the relationship from, this must contain valid id(s)"
        )]
        [Alias("PolicyID")]
        [string]$Id,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The app policy relationship to remove, such as targeted apps or group assignments"
        )]
        [ValidateSet("apps", "assignments")]
        [string]$Relationship,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The relationship ids of the objects to remove from the policy"
        )]
        [Alias('RelationshipID', "AppId", "AppIds", "AssignmentId", "AssignmentIds")]
        [string[]]$RelationshipIDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager App policy type to remove relationships from"
        )]
        [ValidateSet("Protection")]
        [string]$PolicyType = "Protection",
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the App Policy platform to remove relationships from, otherwise all are included"
        )]
        [ValidateSet("Android", "iOS")]
        [string]$Platform
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphDelete.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Removing Endpoint Manager App policy $Relationship relationship"
            $Uri = "deviceAppManagement/targetedManagedAppConfigurations"
            
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
                    AccessToken = $AccessToken
                    Activity    = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # If there are IDs, for each, remove the relationship
                if ($RelationshipIDs) {
                    foreach ($RelationshipId in $RelationshipIDs) {
                        
                        # Remove relationship
                        Invoke-WTGraphDelete `
                            @Parameters `
                            -Uri "$Uri/$Id/$Relationship/$RelationshipId"
                    }
                }
                else {
                    $ErrorMessage = "There are no Endpoint Manager App policy $Relationship to be removed"
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
