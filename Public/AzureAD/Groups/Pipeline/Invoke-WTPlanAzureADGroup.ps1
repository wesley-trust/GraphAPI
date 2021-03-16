function Invoke-WTPlanAzureADGroup {
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
            HelpMessage = "The Azure AD group object"
        )]
        [pscustomobject]$AzureADGroups,
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "If there are no groups to import, whether to forcibly remove any existing groups"
        )]
        [switch]$Force
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\AzureAD\Groups\Get-WTAzureADGroup.ps1"
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
                Write-Host "Evaluating Azure AD Groups"
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters += @{
                        ExcludePreviewFeatures = $true
                    }
                }

                # Evaluate groups if parameters exist
                if ($RemoveExistingGroups -or $UpdateExistingGroups) {

                    # Get existing groups for comparison
                    $ExistingGroups = Get-WTAzureADGroup @Parameters

                    if ($ExistingGroups) {

                        if ($AzureADGroups) {

                            # Compare object on id and pass thru all objects, including those that exist and are to be imported
                            $GroupComparison = Compare-Object `
                                -ReferenceObject $ExistingGroups `
                                -DifferenceObject $AzureADGroups `
                                -Property id `
                                -PassThru

                            # Filter for groups that should be removed, as they do not exist in the import
                            $RemoveGroups = $GroupComparison | Where-Object { $_.sideindicator -eq "<=" }

                            # Filter for groups that did not contain an id, and so are groups that should be created
                            $CreateGroups = $GroupComparison | Where-Object { $_.sideindicator -eq "=>" }
                        }
                        else {

                            # If force is enabled, then if removal of groups is specified, all existing will be removed
                            if ($Force) {
                                $RemoveGroups = $ExistingGroups
                            }
                        }

                        if (!$RemoveExistingGroups) {

                            # If groups are not to be removed, disregard any groups for removal
                            $RemoveGroups = $null
                        }
                        if ($UpdateExistingGroups) {
                            if ($AzureADGroups) {
                                
                                # Check whether the groups that could be updated have valid ids (so can be updated, ignore the rest)
                                $UpdateGroups = foreach ($Group in $AzureADGroups) {
                                    if ($Group.id -in $ExistingGroups.id) {
                                        $Group
                                    }
                                }

                                # If groups exist, with ids that matched the import
                                if ($UpdateGroups) {
                            
                                    # Compare again, with all mandatory property elements for differences
                                    $GroupPropertyComparison = Compare-Object `
                                        -ReferenceObject $ExistingGroups `
                                        -DifferenceObject $UpdateGroups `
                                        -Property id, displayName, description, membershipRule

                                    $UpdateGroups = $GroupPropertyComparison | Where-Object { $_.sideindicator -eq "=>" }
                                }
                            }
                        }
                    }
                    else {
                        # If no groups exist, any imported must be created
                        $CreateGroups = $AzureADGroups
                    }
                }
                else {
                    # If no groups are to be removed or updated, any imported must be created
                    $CreateGroups = $AzureADGroups
                }
                
                # Build object to return
                $PlanAzureADGroups = [ordered]@{}

                if ($RemoveGroups) {
                    $PlanAzureADGroups.Add("RemoveGroups", $RemoveGroups)
                    
                    # Output current action
                    Write-Host "Groups to remove: $($RemoveGroups.count)"

                    foreach ($Group in $RemoveGroups) {
                        Write-Host "Remove: Group ID: $($Group.id)" -ForegroundColor DarkRed
                    }
                }
                else {
                    Write-Host "No groups will be removed, as none exist that are different to the import"
                }
                if ($UpdateGroups) {
                    $PlanAzureADGroups.Add("UpdateGroups", $UpdateGroups)
                                        
                    # Output current action
                    Write-Host "Groups to update: $($UpdateGroups.count)"
                    
                    foreach ($Group in $UpdateGroups) {
                        Write-Host "Update: Group ID: $($Group.id)" -ForegroundColor DarkYellow
                    }
                }
                else {
                    Write-Host "No groups will be updated, as none exist that are different to the import"
                }
                if ($CreateGroups) {
                    $PlanAzureADGroups.Add("CreateGroups", $CreateGroups)
                                        
                    # Output current action
                    Write-Host "Groups to create: $($CreateGroups.count)"

                    foreach ($Group in $CreateGroups) {
                        Write-Host "Create: Group Name: $($Group.displayName)" -ForegroundColor DarkGreen
                    }
                }
                else {
                    Write-Host "No groups will be created, as none exist that are different to the import"
                }

                # If there are groups, return PS object
                if ($PlanAzureADGroups) {
                    $PlanAzureADGroups = [pscustomobject]$PlanAzureADGroups
                    $PlanAzureADGroups
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
        
    }
}