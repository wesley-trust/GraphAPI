function New-WTEMDevicePolicy {
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
            HelpMessage = "Specify the Endpoint Manager Device Policies to create"
        )]
        [Alias('DevicePolicy', "PolicyDefinition")]
        [PSCustomObject]$DevicePolicies,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager Device policy type to create"
        )]
        [ValidateSet("Compliance", "Configuration")]
        [string]$PolicyType,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Default group Id to CC on notification messages for compliance policies"
        )]
        [string]$NotificationMessageCCGroupId
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\ScheduledAction\Notification\New-WTEMNotificationTemplate.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\ScheduledAction\Notification\Relationship\New-WTEMNotificationMessage.ps1",
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
            $BlockGracePeriodHours = "24"
            $NotificationGracePeriodHours = "0"
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

                    # If there are compliance policies, and a non-compliance action is not specified, create default action
                    # At least one action is required for the policy to successfully deploy
                    if ($PolicyType -eq "Compliance") {

                        $DevicePolicies = foreach ($Policy in $DevicePolicies) {
                            if (!$Policy.scheduledActionsForRule) {

                                # Create notification template
                                $NotificationTemplateObject = New-WTEMNotificationTemplate -AccessToken $AccessToken `
                                    -DisplayName $Policy.displayName

                                if ($NotificationTemplateObject) {
                        
                                    # Create notification message
                                    $NotificationMessageObject = New-WTEMNotificationMessage -AccessToken $AccessToken `
                                        -NotificationTemplateId $NotificationTemplateObject.Id

                                    if ($NotificationMessageObject) {
                                    
                                        # Build Notification Action Configuration
                                        $NotificationActionConfiguration = [PSCustomObject]@{
                                            "gracePeriodHours"          = $NotificationGracePeriodHours
                                            "actionType"                = "notification"
                                            "notificationTemplateId"    = $NotificationTemplateObject.Id
                                            "notificationMessageCCList" = @(
                                                if ($NotificationMessageCCGroupId) {
                                                    $NotificationMessageCCGroupId
                                                }
                                            )
                                        }
                                    }
                                    else {
                                        $ErrorMessage = "Failed to create notification message but an exception has not occurred"
                                        throw $ErrorMessage
                                    }
                                }
                                else {
                                    $ErrorMessage = "Failed to create notification template but an exception has not occurred"
                                    throw $ErrorMessage
                                }

                                # Build Block Action Configuration
                                $BlockActionConfiguration = [PSCustomObject]@{
                                    "gracePeriodHours"          = $BlockGracePeriodHours
                                    "actionType"                = "block"
                                    "notificationTemplateId"    = "00000000-0000-0000-0000-000000000000"
                                    "notificationMessageCCList" = @()
                                }

                                # Create scheduled action rule object
                                $DefaultScheduledActionsForRule = @(
                                    [PSCustomObject]@{
                                        "ruleName"                      = "Notify then block in 24 hours"
                                        "scheduledActionConfigurations" = @(
                                            if ($BlockActionConfiguration) {
                                                $BlockActionConfiguration
                                            }
                                            if ($NotificationActionConfiguration) {
                                                $NotificationActionConfiguration
                                            }
                                        )
                                    }
                                )
                                
                                # Add to policy
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