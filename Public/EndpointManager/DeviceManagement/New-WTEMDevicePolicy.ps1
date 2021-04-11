function New-WTEMDevicePolicy {
    [cmdletbinding()]
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
            HelpMessage = "Specify the Endpoint Manager Device Policies to create"
        )]
        [Alias('DevicePolicy', "PolicyDefinition")]
        [PSCustomObject]$DevicePolicies,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager Device policy type to create"
        )]
        [ValidateSet("Compliance", "Configuration")]
        [string]$PolicyType = "Compliance"
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
            $Activity = "Creating Endpoint Manager Device $PolicyType policies"
            $CleanUpProperties = (
                "id",
                "createdDateTime",
                "lastModifiedDateTime",
                "SideIndicator",
                "version",
                "roleScopeTagIds",
                "SVC",
                "REF",
                "ENV"
            )
            $DefaultGracePeriodHours = "24"
            $DefaultAction = "block"
            $DefaultScheduledActionsForRule = @(
                [PSCustomObject]@{
                    "ruleName"                      = $null
                    "scheduledActionConfigurations" = @(
                        [PSCustomObject]@{
                            "gracePeriodHours" = $DefaultGracePeriodHours
                            "actionType"       = $DefaultAction
                        }
                    )
                }
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
                if ($PolicyType -eq "Compliance") {
                    $Uri = "deviceManagement/deviceCompliancePolicies"
                }
                elseif ($PolicyType -eq "Configuration") {
                    $Uri = "deviceManagement/deviceConfigurations"
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
                
                # If there are Device Policies to deploy
                if ($DevicePolicies) {

                    # If compliance policy, and a non-compliance action is not specified, include default action
                    if ($PolicyType -eq "Compliance") {
                        $DevicePolicies = foreach ($Policy in $DevicePolicies) {
                            if (!$Policy.scheduledActionsForRule) {
                                $Policy | Add-Member -NotePropertyName "scheduledActionsForRule" -NotePropertyValue $DefaultScheduledActionsForRule
                            }
                            $Policy
                        }
                    }

                    # Create Device Policies
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $DevicePolicies `
                        -Uri $Uri
                }
                else {
                    $ErrorMessage = "There are no Endpoint Manager Device $PolicyType Policies to be created"
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