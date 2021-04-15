function New-WTEMNotificationMessage {
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
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "Specify the notification template Id to create message for"
        )]
        [string]$NotificationTemplateId
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
            $Activity = "Creating Endpoint Manager Notification Message"
            $Uri = "deviceManagement/notificationMessageTemplates"
            $Relationship = "localizedNotificationMessages"
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
            $NotificationSubject = "Action Required: Device not compliant"
            $NotificationMessage = "Your device has reported that it is not compliant with the required security settings to keep data and information safe. Access to services may be restricted within 24 hours if your device continues to be non-compliant. Please contact us as soon as possible to help. Thanks."
            $NotificationMessageTemplate = [PSCustomObject]@{
                "locale"          = "en-gb"
                "subject"         = $NotificationSubject
                "messageTemplate" = $NotificationMessage
                "isDefault"       = $true
            }
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
                    CleanUpProperties = $CleanUpProperties
                    Activity          = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                # If there is a notification message
                if ($NotificationMessageTemplate) {
                    
                    # Create notification message
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $NotificationMessageTemplate `
                        -Uri "$Uri/$NotificationTemplateId/$Relationship"
                }
                else {
                    $ErrorMessage = "There are no Endpoint Manager Notification Messages to be created"
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