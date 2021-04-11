function Remove-WTEMDevicePolicyRelationship {
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
            HelpMessage = "The Endpoint Manager Device policies to remove the relationship from, this must contain valid id(s)"
        )]
        [Alias("PolicyID")]
        [string]$Id,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The relationship ids of the objects to remove from the policy"
        )]
        [Alias('RelationshipID', "AssignmentId", "AssignmentIds")]
        [string[]]$RelationshipIDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager Device policy type to get"
        )]
        [ValidateSet("Compliance", "Configuration")]
        [string]$PolicyType = "Compliance"
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
            $Relationship = "assignments"
            $Activity = "Removing Endpoint Manager Device policy $Relationship relationship"
            
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
                if ($PolicyType -eq "Compliance") {
                    $Uri = "deviceManagement/deviceCompliancePolicies"
                }
                elseif ($PolicyType -eq "Configuration") {
                    $Uri = "deviceManagement/deviceConfigurations"
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
                    $ErrorMessage = "There are no Endpoint Manager Device policy $Relationship to be removed"
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
