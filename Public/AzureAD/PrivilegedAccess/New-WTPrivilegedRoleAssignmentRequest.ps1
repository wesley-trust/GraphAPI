function New-WTPrivilegedRoleAssignmentRequest {
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
            HelpMessage = "The Azure AD role to add to the directory object, this must contain valid id(s)"
        )]
        [string]$ResourceID,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Azure AD role definition to add to the directory object, this must contain valid id(s)"
        )]
        [string]$RoleDefinitionId,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory object ids to add to the Azure AD role"
        )]
        [Alias('AssignmentID', "MemberIDs", "MemberID")]
        [string[]]$AssignmentIDs,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The type of the role assignment request"
        )]
        [ValidateSet("Eligible", "Active")]
        [string]$AssignmentState,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The type of the role assignment request"
        )]
        [ValidateSet("Add", "Remove", "Activate", "Deactivate")]
        [string]$RequestType,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The reason for the role assignment request"
        )]
        [string]$Reason
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
            $Activity = "Creating Azure AD Privileged Role Assignment Request"
            $Uri = "privilegedAccess/aadRoles/roleAssignmentRequests"
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

                # Set assignment type
                if ($RequestType -eq "Add") {
                    $Type = "AdminAdd"
                }
                elseif ($RequestType -eq "Remove") {
                    $Type = "AdminRemove"
                }
                elseif ($RequestType -eq "Activate") {
                    $Type = "UserAdd"
                }
                elseif ($RequestType -eq "Deactivate") {
                    $Type = "UserRemove"
                }

                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                    Activity    = $Activity
                    Uri         = $Uri
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # If there are IDs, for each, create an appropriate object with the IDs
                if ($AssignmentIDs) {

                    # Build schedule object
                    $Schedule = [PSCustomObject]@{
                        startDateTime = Get-Date -Format "o" -AsUTC
                        endDateTime   = $null
                        #duration = "PT0S"
                        type          = "Once"
                    }

                    # Build assignment request object
                    $AssignmentRequestObjects = foreach ($AssignmentID in $AssignmentIDs) {
                        [PSCustomObject]@{
                            resourceId       = $ResourceID
                            roleDefinitionId = $RoleDefinitionId
                            subjectId        = $AssignmentID
                            assignmentState  = $AssignmentState
                            type             = $Type
                            reason           = $Reason
                            schedule         = $Schedule
                        }
                    }
                    
                    # Add role to directory object
                    Invoke-WTGraphPost `
                        @Parameters `
                        -InputObject $AssignmentRequestObjects
                }
                else {
                    $ErrorMessage = "There are no $Assignment to add the Azure AD roles"
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