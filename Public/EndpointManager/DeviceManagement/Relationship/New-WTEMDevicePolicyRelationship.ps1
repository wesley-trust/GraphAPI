function New-WTEMDevicePolicyRelationship {
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
            HelpMessage = "The Endpoint Manager Device policies to create the relationship with, this must contain valid id(s)"
        )]
        [Alias("PolicyID", "PolicyIDs")]
        [string]$ID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The ids of the include group to assign to the Endpoint Manager Device protection policy"
        )]
        [Alias('IncludeAssignmentID')]
        [string[]]$IncludeAssignmentIDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The ids of the exclude group to assign to the Endpoint Manager Device protection policy"
        )]
        [Alias('ExcludeAssignmentID')]
        [string[]]$ExcludeAssignmentIDs,
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
                "GraphAPI\Private\Invoke-WTGraphPost.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Relationship = "assign"
            $Activity = "Adding Endpoint Manager Device policy $Relationship relationship"

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
                    Uri         = "$Uri/$Id/$Relationship"
                    Activity    = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # If there are assignment IDs, build an object to add these, else, build an device object for each device
                if ($IncludeAssignmentIds -or $ExcludeAssignmentIDs) {
                    
                    # Build Assignment objects
                    if ($IncludeAssignmentIDs) {
                        $IncludeAssignmentObject = [PSCustomObject]@{
                            "target" = foreach ($IncludeAssignmentId in $IncludeAssignmentIDs) {
                                [PSCustomObject]@{
                                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                                    "groupId"     = $IncludeAssignmentId
                                }
                            }
                        }
                    }
                    if ($ExcludeAssignmentIDs) {
                        $ExcludeAssignmentObject = [PSCustomObject]@{    
                            "target" = foreach ($ExcludeAssignmentId in $ExcludeAssignmentIDs) {
                                [PSCustomObject]@{
                                    "@odata.type" = "#microsoft.graph.exclusionGroupAssignmentTarget"
                                    "groupId"     = $ExcludeAssignmentId
                                }
                            }
                        }
                    }

                    # Build input object
                    $InputObject = [PSCustomObject]@{
                        "assignments" = @(
                            if ($IncludeAssignmentObject) {
                                $IncludeAssignmentObject
                            } 
                            if ($ExcludeAssignmentObject) {
                                $ExcludeAssignmentObject
                            }
                        )
                    }
                }

                if ($InputObject) {

                    # Add device policy relationship
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $InputObject
                }
                else {
                    $ErrorMessage = "There are no Endpoint Manager Device policy $Relationship relationships to be added"
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