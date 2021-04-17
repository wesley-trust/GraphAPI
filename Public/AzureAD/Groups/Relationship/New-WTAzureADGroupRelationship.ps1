function New-WTAzureADGroupRelationship {
    [CmdletBinding()]
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Azure AD group to add the members or owners to, this must contain valid id(s)"
        )]
        [Alias("GroupID")]
        [string]$ID,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The group relationship to add, such as group members or owners"
        )]
        [ValidateSet("members", "owners", "assignLicense")]
        [string]$Relationship,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The relationship ids of the objects to add to the group"
        )]
        [Alias('RelationshipID', 'GroupRelationshipID', 'GroupRelationshipIDs')]
        [string[]]$RelationshipIDs
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
            $Activity = "Adding Azure AD group $Relationship"
            $Uri = "groups"
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
                if ($Relationship -eq "assignLicense") {
                    $Parameters.Add("Uri", "$Uri/$Id/$Relationship")
                }
                else {
                    $Parameters.Add("Uri", "$Uri/$Id/$Relationship/`$ref")
                }

                # If there are IDs, for each, create an appropriate object with the IDs
                if ($RelationshipIDs) {
                    if ($Relationship -eq "assignLicense") {
                        $Licences = foreach ($RelationshipId in $RelationshipIDs) {
                            [PSCustomObject]@{
                                "skuId" = $RelationshipId
                            }
                        }
                        $RelationshipObject = [PSCustomObject]@{
                            addLicenses = @(
                                $Licences
                            )
                        }
                    }
                    else {
                        $RelationshipObject = foreach ($RelationshipId in $RelationshipIDs) {
                            [PSCustomObject]@{
                                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$RelationshipId"
                            }
                        }
                    }

                    # Add group relationship
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $RelationshipObject
                }
                else {
                    $ErrorMessage = "There are no group $Relationship to be added"
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