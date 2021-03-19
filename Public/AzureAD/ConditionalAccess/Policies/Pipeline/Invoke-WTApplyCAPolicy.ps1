function Invoke-WTApplyCAPolicy {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Conditional Access Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Conditional Access Graph permissions"
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
            HelpMessage = "The Conditional Access policy object"
        )]
        [pscustomobject]$ConditionalAccessPolicies,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Override the policy state when imported"
        )]
        [ValidateSet("enabled", "enabledForReportingButNotEnforced", "disabled", "")]
        [AllowNull()]
        [String]
        $PolicyState,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to update existing policies deployed in the tenant, where the IDs match"
        )]
        [switch]
        $UpdateExistingPolicies,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing policies deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveExistingPolicies,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to the groups used for CA policies, should not be removed, if the policy is removed"
        )]
        [switch]
        $ExcludeGroupRemoval,
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
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Remove-WTCAPolicy.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\New-WTCAPolicy.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Groups\New-WTCAGroup.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Edit-WTCAPolicy.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Export-WTCAPolicy.ps1",
                "GraphAPI\Public\AzureAD\Groups\Export-WTAzureADGroup.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Groups\Remove-WTCAGroup.ps1",
                "GraphAPI\Public\AzureAD\Groups\Relationship\New-WTAzureADGroupRelationship.ps1"
            )
            
            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }
            
            # Variables
            $Tags = @("REF", "ENV")
            $PropertyToTag = "DisplayName"
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
                Write-Host "Deploying Conditional Access Policies"
                                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                if ($RemoveExistingPolicies) {

                    # If policies require removing, pass the ids to the remove function
                    if ($ConditionalAccessPolicies.RemovePolicies) {
                        $PolicyIDs = $ConditionalAccessPolicies.RemovePolicies.id
                        Remove-WTCAPolicy @Parameters -PolicyIDs $PolicyIDs

                        # If the switch to not remove groups is not set, remove the groups for each Conditional Access policy also
                        if (!$ExcludeGroupRemoval) {
                                
                            # Policy Include groups
                            $PolicyIncludeGroupIDs = $ConditionalAccessPolicies.RemovePolicies.conditions.users.includeGroups
                                
                            # Policy Exclude groups
                            $PolicyExcludeGroupIDs = $ConditionalAccessPolicies.RemovePolicies.conditions.users.excludeGroups
                                
                            # Combined unique list
                            $PolicyGroupIDs = $PolicyIncludeGroupIDs + $PolicyExcludeGroupIDs | Sort-Object -Unique

                            # Pass all groups, which will perform a check and remove only Conditional Access groups
                            Remove-WTCAGroup @Parameters -IDs $PolicyGroupIDs
                        }
                    }
                    else {
                        $WarningMessage = "No policies will be removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }
                if ($UpdateExistingPolicies) {
   
                    # If policies require updating, pass the ids
                    if ($ConditionalAccessPolicies.UpdatePolicies) {
                        Edit-WTCAPolicy @Parameters -ConditionalAccessPolicies $ConditionalAccessPolicies.UpdatePolicies -PolicyState $PolicyState
                    }
                    else {
                        $WarningMessage = "No policies will be updated, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new policies to be created, create them, passing through the policy state
                if ($ConditionalAccessPolicies.CreatePolicies) {
                    $CreatePolicies = $ConditionalAccessPolicies.CreatePolicies
                    
                    # Remove existing tags, so these can be updated from the display name
                    foreach ($Tag in $Tags) {
                        $CreatePolicies | Foreach-Object {
                            $_.PSObject.Properties.Remove($Tag)
                        }
                    }

                    # Evaluate the tags on the policies to be created
                    $TaggedPolicies = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $CreatePolicies -PropertyToTag $PropertyToTag

                    # Calculate the display names to be used for the CA groups (excluding the policy that targets admin roles)
                    $CAIncludeGroupDisplayNames = foreach ($Policy in $TaggedPolicies) {
                        $DisplayName = $null
                        if ($Policy.displayName -notlike "*administrators*") {
                            foreach ($Tag in $Tags) {
                                $DisplayName += $Tag + "-" + $Policy.$Tag + ";"
                            }
                            $DisplayName
                        }
                    }
                    $CAExcludeGroupDisplayNames = foreach ($Policy in $TaggedPolicies) {
                        $DisplayName = $null
                        foreach ($Tag in $Tags) {
                            $DisplayName += $Tag + "-" + $Policy.$Tag + ";"
                        }
                        $DisplayName
                    }

                    # Create include and exclude groups
                    $ConditionalAccessIncludeGroups = New-WTCAGroup @Parameters -DisplayNames $CAIncludeGroupDisplayNames -GroupType Include
                    $ConditionalAccessExcludeGroups = New-WTCAGroup @Parameters -DisplayNames $CAExcludeGroupDisplayNames -GroupType Exclude
                    
                    # Tag groups
                    $TaggedCAIncludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $ConditionalAccessIncludeGroups -PropertyToTag $PropertyToTag
                    $TaggedCAExcludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $ConditionalAccessExcludeGroups -PropertyToTag $PropertyToTag

                    # For each policy, find the matching group
                    $CreatePolicies = foreach ($Policy in $TaggedPolicies) {

                        # Add exclude location to policy
                        if ($Policy.displayName -like "*location*") {
                            $Policy.conditions.locations.excludeLocations = @(

                                # If all trusted is not in the list of defined locations, continue adding locations
                                if ("AllTrusted" -notin $Policy.conditions.locations.excludeLocations) {

                                    # If MFA Trusted IPs is in the list of lcoations, add this, and any additional locations from the pipeline (overwriting)
                                    if ("00000000-0000-0000-0000-000000000000" -in $Policy.conditions.locations.excludeLocations) {
                                        "00000000-0000-0000-0000-000000000000"
                                    }
                                    foreach ($ExcludeLocation in ${ENV:EXCLUDELOCATIONID}) {
                                        $ExcludeLocation
                                    }
                                }
                            )
                        }

                        # Find the matching include group
                        $CAIncludeGroup = $null
                        $CAIncludeGroup = $TaggedCAIncludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # If there is a group for this policy (as policies may not always have groups)
                        if ($CAIncludeGroup) {
                            
                            # Filter on user/guest, adding an appropriate member id if supplied
                            if ($Policy.displayName -like "*guests*") {
                                if (${ENV:IncludeGuestGroupID}) {
                                    New-WTAzureADGroupRelationship @Parameters `
                                        -Id $CAIncludeGroup.id `
                                        -Relationship "members" `
                                        -RelationshipIDs ${ENV:INCLUDEGUESTGROUPID}
                                }
                            }
                            else {
                                if (${ENV:IncludeUserGroupID}) {
                                    New-WTAzureADGroupRelationship @Parameters `
                                        -Id $CAIncludeGroup.id `
                                        -Relationship "members" `
                                        -RelationshipIDs ${ENV:INCLUDEUSERGROUPID}
                                }
                            }
                            
                            # Update the policy with the parent group id (which must be in an array)
                            $Policy.conditions.users.includeGroups = @($CAIncludeGroup.id)
                        }

                        # Find the matching exclude group
                        $CAExcludeGroup = $null
                        $CAExcludeGroup = $TaggedCAExcludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # If there is a group for this policy (as policies may not always have groups)
                        if ($CAExcludeGroup) {
                            
                            # Adding an appropriate member id if supplied
                            if (${ENV:ExcludeUserGroupID}) {
                                New-WTAzureADGroupRelationship @Parameters `
                                    -Id $CAExcludeGroup.id `
                                    -Relationship "members" `
                                    -RelationshipIDs ${ENV:EXCLUDEUSERGROUPID}
                            }
                            
                            # Update the policy with the parent group id (which must be in an array)
                            $Policy.conditions.users.excludeGroups = @($CAExcludeGroup.id)
                        }

                        # Return the policy
                        $Policy
                    }

                    # Create policies
                    $CreatedPolicies = New-WTCAPolicy @Parameters `
                        -ConditionalAccessPolicies $CreatePolicies `
                        -PolicyState $PolicyState
                        
                    # Update configuration files
                    
                    # Export policies
                    Export-WTCAPolicy -ConditionalAccessPolicies $CreatedPolicies `
                        -Path $Path `
                        -ExcludeExportCleanup

                    # Path to group config
                    $GroupsPath = $Path + "\..\Groups"
                    
                    # Export include groups
                    Export-WTAzureADGroup -AzureADGroups $ConditionalAccessIncludeGroups `
                        -Path $GroupsPath `
                        -ExcludeExportCleanup `
                        -DirectoryTag "ENV"

                    # Export exclude groups
                    Export-WTAzureADGroup -AzureADGroups $ConditionalAccessExcludeGroups `
                        -Path $GroupsPath `
                        -ExcludeExportCleanup `
                        -DirectoryTag "ENV"
                    
                    # If executing in a pipeline, stage, commit and push the changes back to the repo
                    if ($Pipeline) {
                        Write-Host "Commit configuration changes post pipeline deployment"
                        Set-Location ${ENV:REPOHOME}
                        git config user.email AzurePipeline@wesleytrust.com
                        git config user.name AzurePipeline
                        git add -A
                        git commit -a -m "Commit configuration changes post deployment [skip ci]"
                        git push https://${ENV:GITHUBPAT}@github.com/wesley-trust/GraphAPIConfig.git HEAD:${ENV:BRANCH}
                    }
                }
                else {
                    $WarningMessage = "No policies will be created, as none exist that are different to the import"
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