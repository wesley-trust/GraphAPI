function Invoke-WTApplyRole {
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
            HelpMessage = "The Role object"
        )]
        [Alias("Role", "RoleDefinition", "Roles")]
        [PSCustomObject]$DefinedRoles,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing roles deployed in the tenant will be activated, if not present in the import"
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
            HelpMessage = "The file path to the JSON file(s) that will be exported"
        )]
        [string]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory path(s) of which all JSON file(s) will be exported"
        )]
        [string]$Path,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether the function is operating within a pipeline"
        )]
        [switch]$Pipeline
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\Roles\Groups\New-WTAADRoleGroup.ps1",
                "GraphAPI\Public\AzureAD\Roles\Export-WTAzureADActivatedRole.ps1",
                "GraphAPI\Public\AzureAD\Roles\Relationship\New-WTAzureADRoleRelationship.ps1",
                "GraphAPI\Public\AzureAD\Groups\Export-WTAzureADGroup.ps1"
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
                Write-Host "Deploying Roles"

                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                if ($ActivateDefinedRoles) {

                    # If roles require activating, pass the objects with just the template ids to the activate function
                    if ($DefinedRoles.ActivateRoles) {
                        $ActivateRoles = $DefinedRoles.ActivateRoles | Select-Object roleTemplateId

                        # Activate role
                        $ActivatedRoles = New-WTAzureADActivatedRole @Parameters `
                            -Roles $ActivateRoles
                    
                        # Path to group config
                        $GroupsPath = $Path + "\..\Groups"

                        # For each role, perform role specific changes
                        foreach ($Role in $ActivatedRoles) {
                    
                            # Create Group
                            $RoleGroup = New-WTAADRoleGroup @Parameters -DisplayName $Role.DisplayName
                    
                            # If there is a group for this role (as roles may not always have groups)
                            if ($RoleGroup) {
                    
                                # Assign role to group
                                New-WTAzureADRoleRelationship @Parameters `
                                    -Id $Role.Id `
                                    -RelationshipIDs $RoleGroup.id `
                                | Out-Null
                                                
                                # Export group
                                Export-WTAzureADGroup -AzureADGroups $RoleGroup `
                                    -Path $GroupsPath `
                                    -ExcludeExportCleanup `
                                    -ExcludeTagEvaluation
                            }
                        }
                    
                        # Export roles
                        Export-WTAzureADActivatedRole -DefinedRoles $ActivatedRoles `
                            -Path $Path `
                            -ExcludeExportCleanup
                    }
                    else {
                        $WarningMessage = "No roles will be activated, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new roles create the groups
                if ($DefinedRoles.CreateRoles) {
                    $CreateRoles = $DefinedRoles.CreateRoles

                    # Path to group config
                    $GroupsPath = $Path + "\..\Groups"

                    # For each role, perform role specific changes
                    foreach ($Role in $CreateRoles) {

                        # Create Group
                        $RoleGroup = New-WTAADRoleGroup @Parameters -DisplayName $Role.DisplayName

                        # If there is a group for this role (as roles may not always have groups)
                        if ($RoleGroup) {

                            # Assign role to group
                            New-WTAzureADRoleRelationship @Parameters `
                                -Id $Role.Id `
                                -RelationshipIDs $RoleGroup.id `
                            | Out-Null
                            
                            # Export group
                            Export-WTAzureADGroup -AzureADGroups $RoleGroup `
                                -Path $GroupsPath `
                                -ExcludeExportCleanup `
                                -ExcludeTagEvaluation
                        }
                    }

                    # Export roles
                    Export-WTAzureADActivatedRole -DefinedRoles $CreateRoles `
                        -Path $Path `
                        -ExcludeExportCleanup
                }
                else {
                    $WarningMessage = "No roles will be created, as none exist that are different to the import"
                    Write-Warning $WarningMessage
                }

                # If executing in a pipeline, stage, commit and push the changes back to the repo
                if ($Pipeline) {
                    Write-Host "Commit configuration changes post pipeline deployment"
                    Set-Location ${ENV:REPOHOME}
                    git config user.email AzurePipeline@wesleytrust.com
                    git config user.name AzurePipeline
                    git add -A
                    git commit -a -m "Commit configuration changes post deployment [skip ci]"
                    git push https://${ENV:GITHUBPAT}@github.com/wesley-trust/${ENV:GITHUBCONFIGREPO}.git HEAD:${ENV:BRANCH}
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