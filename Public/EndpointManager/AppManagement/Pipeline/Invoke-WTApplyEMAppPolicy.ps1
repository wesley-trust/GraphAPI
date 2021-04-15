function Invoke-WTApplyEMAppPolicy {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Endpoint Manager Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Endpoint Manager Graph permissions"
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
            HelpMessage = "The Endpoint Manager App policy object"
        )]
        [Alias('EMAppPolicy', 'PolicyDefinition')]
        [PSCustomObject]$EMAppPolicies,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Android apps (if any) to be targeted by the policies"
        )]
        [Alias("AndroidApp")]
        [PSCustomObject]$AndroidApps,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the iOS apps (if any) to be targeted by the policies"
        )]
        [Alias("iOSApp")]
        [PSCustomObject]$iOSApps,
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
            HelpMessage = "Specify whether to the groups used for EMApp policies, should not be removed, if the policy is removed"
        )]
        [switch]
        $ExcludeGroupRemoval,
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
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\EndpointManager\Groups\New-WTEMGroup.ps1",
                "GraphAPI\Public\EndpointManager\Groups\Remove-WTEMGroup.ps1",
                "GraphAPI\Public\EndpointManager\AppManagement\Remove-WTEMAppPolicy.ps1",
                "GraphAPI\Public\EndpointManager\AppManagement\New-WTEMAppPolicy.ps1",
                "GraphAPI\Public\EndpointManager\AppManagement\Edit-WTEMAppPolicy.ps1",
                "GraphAPI\Public\EndpointManager\AppManagement\Export-WTEMAppPolicy.ps1",
                "GraphAPI\Public\AzureAD\Groups\Export-WTAzureADGroup.ps1",
                "GraphAPI\Public\AzureAD\Groups\Relationship\New-WTAzureADGroupRelationship.ps1",
                "GraphAPI\Public\EndpointManager\AppManagement\Relationship\Get-WTEMAppPolicyRelationship.ps1",
                "GraphAPI\Public\EndpointManager\AppManagement\Relationship\New-WTEMAppPolicyRelationship.ps1"
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
                Write-Host "Deploying Endpoint Manager App Policies"
                                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                if ($RemoveExistingPolicies) {

                    # If policies require removing
                    if ($EMAppPolicies.RemovePolicies) {

                        # If the switch to not remove groups is not set, remove the groups for each Endpoint Manager policy also
                        if (!$ExcludeGroupRemoval) {
                            
                            ## Get policy assignments
                            $PolicyAssignments = Get-WTEMAppPolicyRelationship @Parameters `
                                -Ids $EMAppPolicies.RemovePolicies.id `
                                -Relationship "assignments" -
                                
                            # Filter to group ids and unique list
                            $PolicyGroupIDs = $PolicyAssignments.target.groupId | Sort-Object -Unique

                            # Pass all groups, which will perform a check and remove only Endpoint Manager groups
                            Remove-WTEMGroup @Parameters -IDs $PolicyGroupIDs
                        }

                        # Pass the ids of the policies to the remove function
                        Remove-WTEMAppPolicy @Parameters -PolicyIDs $EMAppPolicies.RemovePolicies.id
                    }
                    else {
                        $WarningMessage = "No policies will be removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }
                if ($UpdateExistingPolicies) {
   
                    # If policies require updating, pass the policies
                    if ($EMAppPolicies.UpdatePolicies) {
                        Edit-WTEMAppPolicy @Parameters -EMAppPolicies $EMAppPolicies.UpdatePolicies
                    }
                    else {
                        $WarningMessage = "No policies will be updated, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new policies to be created, create them
                if ($EMAppPolicies.CreatePolicies) {
                    $CreatePolicies = $EMAppPolicies.CreatePolicies
                    
                    # Remove existing tags, so these can be updated from the display name
                    foreach ($Tag in $Tags) {
                        $CreatePolicies | Foreach-Object {
                            $_.PSObject.Properties.Remove($Tag)
                        }
                    }

                    # Evaluate the tags on the policies to be created
                    $TaggedPolicies = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $CreatePolicies -PropertyToTag $PropertyToTag

                    # Calculate the display names to be used for the EMApp groups (excluding the policy that targets admin roles)
                    $EMAppGroupDisplayNames = foreach ($Policy in $TaggedPolicies) {
                        $DisplayName = $null
                        foreach ($Tag in $Tags) {
                            $DisplayName += $Tag + "-" + $Policy.$Tag + ";"
                        }
                        $DisplayName
                    }

                    # Create include and exclude groups
                    $EMAppIncludeGroups = New-WTEMGroup @Parameters -DisplayNames $EMAppGroupDisplayNames -GroupType Include
                    $EMAppExcludeGroups = New-WTEMGroup @Parameters -DisplayNames $EMAppGroupDisplayNames -GroupType Exclude
                    
                    # Tag groups
                    $TaggedEMAppIncludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $EMAppIncludeGroups -PropertyToTag $PropertyToTag
                    $TaggedEMAppExcludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $EMAppExcludeGroups -PropertyToTag $PropertyToTag

                    # For each policy, perform policy specific changes
                    $CreatedPolicies = foreach ($Policy in $TaggedPolicies) {

                        # Create and return the policy
                        $CreatedPolicy = $null
                        New-WTEMAppPolicy @Parameters -EMAppPolicies $Policy | Tee-Object -Variable CreatedPolicy

                        # Find the matching include group
                        $EMAppIncludeGroup = $null
                        $EMAppIncludeGroup = $TaggedEMAppIncludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # Adding an appropriate member id if supplied
                        if (${ENV:IncludeUserGroupID}) {
                            New-WTAzureADGroupRelationship @Parameters `
                                -Id $EMAppIncludeGroup.id `
                                -Relationship "members" `
                                -RelationshipIDs ${ENV:INCLUDEUSERGROUPID}
                        }

                        # Find the matching exclude group
                        $EMAppExcludeGroup = $null
                        $EMAppExcludeGroup = $TaggedEMAppExcludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # Adding an appropriate member id if supplied
                        if (${ENV:ExcludeUserGroupID}) {
                            New-WTAzureADGroupRelationship @Parameters `
                                -Id $EMAppExcludeGroup.id `
                                -Relationship "members" `
                                -RelationshipIDs ${ENV:EXCLUDEUSERGROUPID}
                        }

                        # Create assignment relationship
                        New-WTEMAppPolicyRelationship @Parameters `
                            -Id $CreatedPolicy.id `
                            -Relationship "assign" `
                            -IncludeAssignmentID $EMAppIncludeGroup.id `
                            -ExcludeAssignmentID $EMAppExcludeGroup.id

                        # Create apps relationship for each platform, if applicable
                        if ($CreatedPolicy.target.'@odata.type' -eq "#microsoft.graph.androidManagedAppProtection") {
                            if ($AndroidApps) {
                                New-WTEMAppPolicyRelationship @Parameters `
                                    -Id $CreatedPolicy.id `
                                    -Relationship "apps" `
                                    -PolicyType "Protection" `
                                    -Platform "Android" `
                                    -Apps $AndroidApps
                            }
                        }
                        elseif ($CreatedPolicy.target.'@odata.type' -eq "#microsoft.graph.iOSManagedAppProtection") {
                            if ($iOSApps) {
                                New-WTEMAppPolicyRelationship @Parameters `
                                    -Id $CreatedPolicy.id `
                                    -Relationship "apps" `
                                    -PolicyType "Protection" `
                                    -Platform "iOS" `
                                    -Apps $iOSApps
                            }
                        }
                    }
                    
                    # Export policies
                    Export-WTEMAppPolicy -EMAppPolicies $CreatedPolicies `
                        -Path $Path `
                        -ExcludeExportCleanup

                    # Path to group config
                    $GroupsPath = $Path + "\..\..\Groups"
                    
                    # Export include groups
                    Export-WTAzureADGroup -AzureADGroups $EMAppIncludeGroups `
                        -Path $GroupsPath `
                        -ExcludeExportCleanup `
                        -DirectoryTag "ENV"

                    # Export exclude groups
                    Export-WTAzureADGroup -AzureADGroups $EMAppExcludeGroups `
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
                        git push https://${ENV:GITHUBPAT}@github.com/wesley-trust/${ENV:GITHUBCONFIGREPO}.git HEAD:${ENV:BRANCH}
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