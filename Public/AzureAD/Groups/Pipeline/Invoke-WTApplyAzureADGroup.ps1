function Invoke-WTApplyAzureADGroup {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with AzureAD Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with AzureAD Graph permissions"
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
            HelpMessage = "The AzureAD group object"
        )]
        [Alias('AzureADGroup', 'GroupDefinition')]
        [PSCustomObject]$AzureADGroups,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to update existing groups deployed in the tenant, where the IDs match"
        )]
        [switch]
        $UpdateExistingGroups,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing groups deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveExistingGroups,
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
                "GraphAPI\Public\AzureAD\Groups\Remove-WTAzureADGroup.ps1",
                "GraphAPI\Public\AzureAD\Groups\New-WTAzureADGroup.ps1",
                "GraphAPI\Public\AzureAD\Groups\Edit-WTAzureADGroup.ps1",
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
                Write-Host "Deploying Azure AD Groups"
                                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                if ($RemoveExistingGroups) {

                    # If groups require removing, pass the ids to the remove function
                    if ($AzureADGroups.RemoveGroups) {
                        $GroupIDs = $AzureADGroups.RemoveGroups.id
                        Remove-WTAzureADGroup @Parameters -GroupIDs $GroupIDs
                    }
                    else {
                        $WarningMessage = "No groups will be removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }
                if ($UpdateExistingGroups) {
   
                    # If groups require updating, pass the ids
                    if ($AzureADGroups.UpdateGroups) {
                        Edit-WTAzureADGroup @Parameters -AzureADGroups $AzureADGroups.UpdateGroups
                    }
                    else {
                        $WarningMessage = "No groups will be updated, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new groups to be created, create them, passing through the group state
                if ($AzureADGroups.CreateGroups) {

                    # Create groups
                    $CreatedGroups = New-WTAzureADGroup @Parameters `
                        -AzureADGroups $AzureADGroups.CreateGroups
                        
                    # Update configuration files
                    
                    # Export groups
                    Export-WTAzureADGroup -AzureADGroups $CreatedGroups `
                        -Path $Path `
                        -ExcludeExportCleanup
                    
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
                    $WarningMessage = "No groups will be created, as none exist that are different to the import"
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