function Get-WTAzureADGroupRelationship {
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
            HelpMessage = "Specify whether to exclude tag processing of groups"
        )]
        [switch]$ExcludeTagEvaluation,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Azure AD group to get the members of, this must contain valid id(s)"
        )]
        [Alias("id", "GroupID", "GroupIDs")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The group relationship to return, such as group members, owners or groups this group is a member of"
        )]
        [ValidateSet("members", "owners", "memberOf")]
        [string]$Relationship
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphGet.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Getting Azure AD group $Relationship"
            $Uri = "groups"
            $Tags = @("SVC", "REF", "ENV")

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
                    Activity    = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                if (!$ExcludeTagEvaluation) {
                    $Parameters.Add("Tags", $Tags)
                }

                # Get Azure AD group relationship
                $QueryResponse = foreach ($Id in $IDs) {
                    Invoke-WTGraphGet @Parameters -Uri "$Uri/$Id/$Relationship"
                }

                # Return response if one is returned
                if ($QueryResponse) {
                    $QueryResponse
                }
                else {
                    $WarningMessage = "No group relationship exists in Azure AD for any of the group IDs specified"
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
