function New-WTAzureADGroup {
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
            HelpMessage = "Specify the Azure AD Groups to create"
        )]
        [Alias('AzureADGroup')]
        [pscustomobject]$AzureADGroups
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphPost.ps1",
                "Toolkit\Public\New-WTRandomString.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Creating Azure AD groups"
            $Uri = "groups"
            $CleanUpProperties = (
                "id",
                "createdDateTime",
                "modifiedDateTime",
                "SideIndicator",
                "securityIdentifier",
                "createdByAppId",
                "renewedDateTime",
                "SVC",
                "REF",
                "ENV"
            )
            $Service = "AD"

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
                    AccessToken       = $AccessToken
                    Uri               = $Uri
                    CleanUpProperties = $CleanUpProperties
                    Activity          = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                # If there are groups to deploy, for each
                if ($AzureADGroups) {

                    # Foreach group, check whether the required mailNickname exists, if not, generate this, append and return group
                    $AzureADGroups = foreach ($Group in $AzureADGroups){
                        if (!$Group.mailNickname){
                            $mailNickname = $null
                            $mailNickname = $Service + "-" + (New-WTRandomString -CharacterLength 48 -Alphanumeric)
                            $Group | Add-Member -MemberType NoteProperty -Name "mailNickname" -Value $mailNickname
                        }
                        
                        # Return group
                        $Group
                    }
                    
                    # Create groups
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $AzureADGroups
                }
                else {
                    $ErrorMessage = "There are no groups to be created"
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