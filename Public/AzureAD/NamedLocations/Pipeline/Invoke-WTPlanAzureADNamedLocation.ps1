function Invoke-WTPlanAzureADNamedLocation {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Azure AD Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Azure AD Graph permissions"
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
            HelpMessage = "The Azure AD named location object"
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "If there are no named locations to import, whether to forcibly remove any existing named locations"
        )]
        [switch]$Force
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\Get-WTAzureADNamedLocation.ps1"
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
                Write-Host "Evaluating Azure AD Named Locations"
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # Evaluate named locations if parameters exist
                if ($RemoveExistingNamedLocations -or $UpdateExistingNamedLocations) {

                    # Get existing named locations for comparison
                    $ExistingNamedLocations = Get-WTAzureADNamedLocation @Parameters

                    if ($ExistingNamedLocations) {

                        if ($AzureADNamedLocations) {

                            # Compare object on id and pass thru all objects, including those that exist and are to be imported
                            $NamedLocationComparison = Compare-Object `
                                -ReferenceObject $ExistingNamedLocations `
                                -DifferenceObject $AzureADNamedLocations `
                                -Property id `
                                -PassThru

                            # Filter for named locations that should be removed, as they do not exist in the import
                            $RemoveNamedLocations = $NamedLocationComparison | Where-Object { $_.sideindicator -eq "<=" }

                            # Filter for named locations that did not contain an id, and so are named locations that should be created
                            $CreateNamedLocations = $NamedLocationComparison | Where-Object { $_.sideindicator -eq "=>" }
                        }
                        else {

                            # If force is enabled, then if removal of named locations is specified, all existing will be removed
                            if ($Force) {
                                $RemoveNamedLocations = $ExistingNamedLocations
                            }
                        }

                        if (!$RemoveExistingNamedLocations) {

                            # If named locations are not to be removed, disregard any named locations for removal
                            $RemoveNamedLocations = $null
                        }
                        if ($UpdateExistingNamedLocations) {
                            if ($AzureADNamedLocations) {
                                
                                # Check whether the named locations that could be updated have valid ids (so can be updated, ignore the rest)
                                $UpdateNamedLocations = foreach ($NamedLocation in $AzureADNamedLocations) {
                                    if ($NamedLocation.id -in $ExistingNamedLocations.id) {
                                        $NamedLocation
                                    }
                                }

                                # If named locations exist, with ids that matched the import
                                if ($UpdateNamedLocations) {
                            
                                    # Compare again, with all mandatory property elements for differences
                                    $NamedLocationPropertyComparison = Compare-Object `
                                        -ReferenceObject $ExistingNamedLocations `
                                        -DifferenceObject $UpdateNamedLocations `
                                        -Property id, displayName, countriesAndRegions, includeUnknownCountriesAndRegions

                                    $UpdateNamedLocations = $NamedLocationPropertyComparison | Where-Object { $_.sideindicator -eq "=>" }
                                }
                            }
                        }
                    }
                    else {
                        # If no named locations exist, any imported must be created
                        $CreateNamedLocations = $AzureADNamedLocations
                    }
                }
                else {
                    # If no named locations are to be removed or updated, any imported must be created
                    $CreateNamedLocations = $AzureADNamedLocations
                }
                
                # Build object to return
                $PlanAzureADNamedLocations = [ordered]@{}

                if ($RemoveNamedLocations) {
                    $PlanAzureADNamedLocations.Add("RemoveNamedLocations", $RemoveNamedLocations)
                    
                    # Output current action
                    Write-Host "Named Locations to remove: $($RemoveNamedLocations.count)"

                    foreach ($NamedLocation in $RemoveNamedLocations) {
                        Write-Host "Remove: Named Location ID: $($NamedLocation.id)" -ForegroundColor DarkRed
                    }
                }
                else {
                    Write-Host "No named locations will be removed, as none exist that are different to the import"
                }
                if ($UpdateNamedLocations) {
                    $PlanAzureADNamedLocations.Add("UpdateNamedLocations", $UpdateNamedLocations)
                                        
                    # Output current action
                    Write-Host "Named Locations to update: $($UpdateNamedLocations.count)"
                    
                    foreach ($NamedLocation in $UpdateNamedLocations) {
                        Write-Host "Update: Named Location ID: $($NamedLocation.id)" -ForegroundColor DarkYellow
                    }
                }
                else {
                    Write-Host "No named locations will be updated, as none exist that are different to the import"
                }
                if ($CreateNamedLocations) {
                    $PlanAzureADNamedLocations.Add("CreateNamedLocations", $CreateNamedLocations)
                                        
                    # Output current action
                    Write-Host "Named Locations to create: $($CreateNamedLocations.count)"

                    foreach ($NamedLocation in $CreateNamedLocations) {
                        Write-Host "Create: Named Location Name: $($NamedLocation.displayName)" -ForegroundColor DarkGreen
                    }
                }
                else {
                    Write-Host "No named locations will be created, as none exist that are different to the import"
                }

                # If there are named locations, return PS object
                if ($PlanAzureADNamedLocations) {
                    $PlanAzureADNamedLocations = [pscustomobject]$PlanAzureADNamedLocations
                    $PlanAzureADNamedLocations
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