function Invoke-WTApplyAzureADNamedLocation {
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
            HelpMessage = "The AzureAD named location object"
        )]
        [pscustomobject]$AzureADNamedLocations,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to update existing named locations deployed in the tenant, where the IDs match"
        )]
        [switch]
        $UpdateExistingNamedLocations,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing named locations deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveExistingNamedLocations,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
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
                "GraphAPI\Public\AzureAD\NamedLocations\Remove-WTAzureADNamedLocation.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\New-WTAzureADNamedLocation.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\Edit-WTAzureADNamedLocation.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\Export-WTAzureADNamedLocation.ps1"
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
                Write-Host "Deploying Azure AD Named Locations"
                                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                if ($RemoveExistingNamedLocations) {

                    # If named locations require removing, pass the ids to the remove function
                    if ($AzureADNamedLocations.RemoveNamedLocations) {
                        $NamedLocationIDs = $AzureADNamedLocations.RemoveNamedLocations.id
                        Remove-WTAzureADNamedLocation @Parameters -NamedLocationIDs $NamedLocationIDs
                    }
                    else {
                        $WarningMessage = "No named locations will be removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }
                if ($UpdateExistingNamedLocations) {
   
                    # If named locations require updating, pass the ids
                    if ($AzureADNamedLocations.UpdateNamedLocations) {
                        Edit-WTAzureADNamedLocation @Parameters -AzureADNamedLocations $AzureADNamedLocations.UpdateNamedLocations
                    }
                    else {
                        $WarningMessage = "No named locations will be updated, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new named locations to be created, create them, passing through the named location state
                if ($AzureADNamedLocations.CreateNamedLocations) {

                    # Create named locations
                    $CreatedNamedLocations = New-WTAzureADNamedLocation @Parameters `
                        -AzureADNamedLocations $AzureADNamedLocations.CreateNamedLocations
                        
                    # Update configuration files
                    
                    # Export named locations
                    Export-WTAzureADNamedLocation -AzureADNamedLocations $CreatedNamedLocations `
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
                    $WarningMessage = "No named locations will be created, as none exist that are different to the import"
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