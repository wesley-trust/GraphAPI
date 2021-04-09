function Edit-WTCAPolicy {
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Conditional Access policies to remove, a policy must have a valid id"
        )]
        [Alias('ConditionalAccessPolicy', 'PolicyDefinition')]
        [PSCustomObject]$ConditionalAccessPolicies,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Override the policy state when value specified"
        )]
        [ValidateSet("enabled", "enabledForReportingButNotEnforced", "disabled", "")]
        [AllowNull()]
        [String]
        $PolicyState
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphPatch.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Updating Conditional Access Policies"
            $Uri = "identity/conditionalAccess/policies"
            $CleanUpProperties = (
                "createdDateTime",
                "modifiedDateTime",
                "SideIndicator"
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

                # If there are policies to update, foreach policy with a policy id
                if ($ConditionalAccessPolicies) {
                    
                    if ($PolicyState) {
                        $ConditionalAccessPolicies = foreach ($Policy in $ConditionalAccessPolicies) {

                            # Override policy state 
                            if ($PolicyState) {
                                $Policy.state = "$PolicyState"
                            }
                            
                            # Returned modified object
                            $Policy
                        }
                    }
                    
                    # Update policies
                    Invoke-WTGraphPatch `
                        @Parameters `
                        -InputObject $ConditionalAccessPolicies
                }
                else {
                    $ErrorMessage = "There are no Conditional Access policies to be updated"
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
