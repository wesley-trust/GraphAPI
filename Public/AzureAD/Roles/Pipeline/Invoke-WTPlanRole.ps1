function Invoke-WTPlanRole {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Role Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Role Graph permissions"
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
            ValueFromPipeLine = $true,
            HelpMessage = "The Role object"
        )]
        [Alias("Role", "RoleDefinition", "Roles")]
        [PSCustomObject]$DefinedRoles,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether current Role deployed in the tenant will be activated, if not present in the import"
        )]
        [switch]
        $ActivateDefinedRoles,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "If there are no Role to import, whether to forcibly activate any current Role"
        )]
        [switch]$Force
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\AzureAD\Roles\Get-WTAzureADActivatedRole.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
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

                # Output current action
                Write-Host "Evaluating Roles"
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # Get user roles that have not been deleted
                $ActivatedRoles = Get-WTAzureADActivatedRole @Parameters

                if ($DefinedRoles) {

                    if ($ActivatedRoles) {

                        # Compare object on id and pass thru all objects, including those that exist and are to be imported
                        $RoleComparison = Compare-Object `
                            -ReferenceObject $ActivatedRoles `
                            -DifferenceObject $DefinedRoles `
                            -Property id `
                            -PassThru

                        # Filter for defined Role that should be activated, as they exist only in the import
                        $ActivateRoles = $RoleComparison | Where-Object { $_.sideindicator -eq "=>" }

                        # Filter for defined Role that should be created, as they exist only in Azure AD
                        $CreateRoles = $RoleComparison | Where-Object { $_.sideindicator -eq "<=" }
                    }
                    else {

                        # If force is enabled, then if activation of Role is specified, all current will be activated
                        if ($Force) {
                            $ActivateRoles = $DefinedRoles
                        }
                    }

                    if (!$ActivateDefinedRoles) {

                        # If Role are not to be activated, disregard any Role for activation
                        $ActivateRoles = $null
                    }
                }
                else {
                    
                    # If no defined role exist, any enabled roles should be defined
                    $CreateRoles = $ActivatedRoles
                }
                
                # Build object to return
                $PlanRoles = [ordered]@{}

                if ($ActivateRoles) {
                    $PlanRoles.Add("ActivateRoles", $ActivateRoles)
                    
                    # Output current action
                    Write-Host "Defined Role to activate: $($ActivateRoles.count)"

                    foreach ($Role in $ActivateRoles) {
                        Write-Host "Activate: Role ID: $($Role.id) (Role Groups will be activated as appropriate)" -ForegroundColor DarkRed
                    }
                }
                else {
                    Write-Host "No Role will be activated, as none exist that are different to the import"
                }
                if ($CreateRoles) {
                    $PlanRoles.Add("CreateRoles", $CreateRoles)
                                        
                    # Output current action
                    Write-Host "Defined Role to create: $($CreateRoles.count) (Role Groups will be created as appropriate)"

                    foreach ($Role in $CreateRoles) {
                        Write-Host "Create: Role Name: $($Role.displayName)" -ForegroundColor DarkGreen
                    }
                }
                else {
                    Write-Host "No Role will be created, as none exist that are different to the import"
                }

                # If there are Role, return PS object
                if ($PlanRoles) {
                    $PlanRoles = [PSCustomObject]$PlanRoles
                    $PlanRoles
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