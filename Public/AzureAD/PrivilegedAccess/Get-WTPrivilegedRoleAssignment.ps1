function Get-WTPrivilegedRoleAssignment {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Azure AD role Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Azure AD role Graph permissions"
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
            HelpMessage = "The Azure AD tenant Id, this must contain valid id(s)"
        )]
        [Alias("AzureADTenant")]
        [string]$TenantId,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Azure AD roles to get, this must contain valid id(s)"
        )]
        [Alias("id", "RoleID", "RoleIDs")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Azure AD role assignment state to return, permanently active or eligible"
        )]
        [ValidateSet("Active", "Eligible", "All")]
        [string]$AssignmentState = "All",
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to lookup and return the display name for the roles"
        )]
        [switch]$IncludeDisplayName
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphGet.ps1",
                "GraphAPI\Public\AzureAD\Organisation\Get-WTAzureADOrganisation.ps1",
                "GraphAPI\Public\AzureAD\Roles\Get-WTAzureADActivatedRole.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Getting Azure AD Privileged Role Assignments"
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

                # If the Azure AD tenant is not specified, get Azure AD Organisation information
                if (!$TenantId) {
                    $Organisation = Get-WTAzureADOrganisation -AccessToken $AccessToken
                    $TenantId = $Organisation.Id
                }
                
                # Set resource
                $Uri = "privilegedAccess/aadRoles/resources/$TenantId/roleAssignments"
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                    Activity    = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                if ($IDs) {
                    $Parameters.Add("IDs", $IDs)
                }

                # Get Azure AD roles with default properties
                $QueryResponse = Invoke-WTGraphGet @Parameters -Uri $Uri

                # Return response if one is returned
                if ($QueryResponse) {

                    # If display names are required, get activated roles
                    if ($IncludeDisplayName) {
                        $ActivatedRoles = Get-WTAzureADActivatedRole -AccessToken $AccessToken
                    
                        # For each role assignment returned in the response
                        $Objects = foreach ($Response in $QueryResponse) {
                        
                            # Get the properties of the role
                            $ResponseProperties = ($Response | Get-Member -MemberType NoteProperty).Name
                        
                            # Build a new object containing the existing properties
                            $ObjectProperties = @{}
                            foreach ($Property in $ResponseProperties) {
                                $ObjectProperties.Add($Property, $Response.$Property)
                            }

                            # If the role definition is in the list of activated role templates
                            if ($Response.roleDefinitionId -in $ActivatedRoles.roleTemplateId) {
                            
                                # Filter to the specific template and add the display name to the object
                                $ActivatedRole = foreach ($Role in $ActivatedRoles) {
                                    if ($Response.roleDefinitionId -eq $Role.roleTemplateId) {
                                        $Role
                                    }
                                }
                                if ($ActivatedRole) {
                                    $ObjectProperties.Add("displayName", $ActivatedRole.displayName)
                                }
                            }
                            else {
                                $ObjectProperties.Add("displayName", $null)
                            }
                        
                            # Return the new object
                            [PSCustomObject]$ObjectProperties
                        }
                    
                        # Return the modified response object
                        $Objects
                    }
                    else {
                        
                        # Return original response
                        $QueryResponse
                    }
                }
                else {
                    $WarningMessage = "No Azure AD roles exist in Azure AD, or with parameters specified"
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
        try {
            
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
}
