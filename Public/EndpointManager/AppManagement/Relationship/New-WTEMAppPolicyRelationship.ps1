function New-WTEMAppPolicyRelationship {
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Endpoint Manager App policies to create the relationship with, this must contain valid id(s)"
        )]
        [Alias("PolicyID", "PolicyIDs")]
        [string]$ID,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The group relationship to create, such as target apps or group assignments"
        )]
        [ValidateSet("targetApps", "assign")]
        [string]$Relationship,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The ids of the group to assign to the Endpoint Manager App protection policy"
        )]
        [Alias('AssignmentID')]
        [string[]]$AssignmentIDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the target apps to add to the Endpoint Manager App protection policy"
        )]
        [Alias('App')]
        [PSCustomObject]$Apps,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "Specify the Endpoint Manager App policy type"
        )]
        [ValidateSet("Protection")]
        [string]$PolicyType = "Protection",
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the platform for the Endpoint Manager App policy target app"
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
            $Activity = "Adding Endpoint Manager App policy relationship"

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
                    Uri         = "$Uri/$Id/$Relationship"
                    Activity    = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # Specify platform specific parameters
                if ($PolicyType -eq "Protection") {
                    if ($Platform -eq "Android") {
                        $AppPlatformIdentifier = "androidMobileAppIdentifier"
                        $AppIdentifier = "packageId"
                        $Uri = "deviceAppManagement/androidManagedAppProtections"
                    }
                    elseif ($Platform -eq "iOS") {
                        $AppPlatformIdentifier = "iosMobileAppIdentifier"
                        $AppIdentifier = "bundleId"
                        $Uri = "deviceAppManagement/iosManagedAppProtections"
                    }
                }

                # If there are assignment IDs, build an object to add these, else, build an app object for each app
                if ($AssignmentIDs) {
                    $InputObject = [PSCustomObject]@{
                        "assignments" = @(
                            foreach ($AssignmentId in $AssignmentIDs) {
                                [PSCustomObject]@{
                                    "target" = [PSCustomObject]@{
                                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                                        "groupId"     = $AssignmentId
                                    }
                                }
                            }
                        )
                    }
                }
                elseif ($Apps) {
                    $InputObject = [PSCustomObject]@{
                        "apps" = @(
                            foreach ($App in $Apps) {
                                [PSCustomObject]@{
                                    "@odata.type"         = "#microsoft.graph.managedMobileApp"
                                    "mobileAppIdentifier" = [PSCustomObject]@{
                                        "@odata.type"  = "microsoft.graph.$AppPlatformIdentifier"
                                        $AppIdentifier = $App.mobileAppIdentifier.$AppIdentifier
                                    }
                                    "id"                  = $App.id
                                }
                            }
                        )
                    }
                }
                if ($InputObject) {

                    # Add app policy relationship
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $InputObject
                }
                else {
                    $ErrorMessage = "There are no Endpoint Manager App policy relationships to be added"
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