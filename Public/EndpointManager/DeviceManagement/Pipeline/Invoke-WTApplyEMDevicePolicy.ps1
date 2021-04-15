function Invoke-WTApplyEMDevicePolicy {
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
            HelpMessage = "The Endpoint Manager Device policy object"
        )]
        [Alias('EMDevicePolicy', 'PolicyDefinition')]
        [PSCustomObject]$EMDevicePolicies,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify a group id to notify if a device becomes non-compliant"
        )]
        [string]$NotificationGroupId,
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
            HelpMessage = "Specify whether to the groups used for EMDevice policies, should not be removed, if the policy is removed"
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
                "GraphAPI\Public\EndpointManager\DeviceManagement\Remove-WTEMDevicePolicy.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\New-WTEMDevicePolicy.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\Edit-WTEMDevicePolicy.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\Export-WTEMDevicePolicy.ps1",
                "GraphAPI\Public\AzureAD\Groups\Export-WTAzureADGroup.ps1",
                "GraphAPI\Public\AzureAD\Groups\Relationship\New-WTAzureADGroupRelationship.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\Relationship\Get-WTEMDevicePolicyRelationship.ps1",
                "GraphAPI\Public\EndpointManager\DeviceManagement\Relationship\New-WTEMDevicePolicyRelationship.ps1"
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
                Write-Host "Deploying Endpoint Manager Device Policies"
                                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                
                if ($RemoveExistingPolicies) {

                    # If policies require removing
                    if ($EMDevicePolicies.RemovePolicies) {

                        # If the switch to not remove groups is not set, remove the groups for each Endpoint Manager policy also
                        if (!$ExcludeGroupRemoval) {
                            
                            ## Get policy assignments
                            $PolicyAssignments = Get-WTEMDevicePolicyRelationship @Parameters `
                                -Ids $EMDevicePolicies.RemovePolicies.id `
                                -Relationship "assignments"

                            # Filter to group ids and unique list
                            $PolicyGroupIDs = $PolicyAssignments.target.groupId | Sort-Object -Unique

                            # Pass all groups, which will perform a check and remove only Endpoint Manager groups
                            Remove-WTEMGroup @Parameters -IDs $PolicyGroupIDs
                        }

                        # Pass the ids of the policies to the remove function
                        Remove-WTEMDevicePolicy @Parameters -PolicyIDs $EMDevicePolicies.RemovePolicies.id
                    }
                    else {
                        $WarningMessage = "No policies will be removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }
                if ($UpdateExistingPolicies) {
   
                    # If policies require updating, pass the policies
                    if ($EMDevicePolicies.UpdatePolicies) {
                        Edit-WTEMDevicePolicy @Parameters -EMDevicePolicies $EMDevicePolicies.UpdatePolicies
                    }
                    else {
                        $WarningMessage = "No policies will be updated, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new policies to be created, create them
                if ($EMDevicePolicies.CreatePolicies) {
                    $CreatePolicies = $EMDevicePolicies.CreatePolicies
                    
                    # Remove existing tags, so these can be updated from the display name
                    foreach ($Tag in $Tags) {
                        $CreatePolicies | Foreach-Object {
                            $_.PSObject.Properties.Remove($Tag)
                        }
                    }

                    # Evaluate the tags on the policies to be created
                    $TaggedPolicies = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $CreatePolicies -PropertyToTag $PropertyToTag

                    # Calculate the display names to be used for the EM groups
                    $EMDeviceGroupDisplayNames = foreach ($Policy in $TaggedPolicies) {
                        $DisplayName = $null
                        foreach ($Tag in $Tags) {
                            $DisplayName += $Tag + "-" + $Policy.$Tag + ";"
                        }
                        $DisplayName
                    }

                    # Create include and exclude groups
                    $EMDeviceIncludeGroups = New-WTEMGroup @Parameters -DisplayNames $EMDeviceGroupDisplayNames -GroupType Include
                    $EMDeviceExcludeGroups = New-WTEMGroup @Parameters -DisplayNames $EMDeviceGroupDisplayNames -GroupType Exclude

                    # Tag groups
                    $TaggedEMDeviceIncludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $EMDeviceIncludeGroups -PropertyToTag $PropertyToTag
                    $TaggedEMDeviceExcludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $EMDeviceExcludeGroups -PropertyToTag $PropertyToTag

                    # For each policy, perform policy specific changes
                    $CreatedPolicies = foreach ($Policy in $TaggedPolicies) {

                        # Find the matching include group
                        $EMDeviceIncludeGroup = $null
                        $EMDeviceIncludeGroup = $TaggedEMDeviceIncludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # Find the matching exclude group
                        $EMDeviceExcludeGroup = $null
                        $EMDeviceExcludeGroup = $TaggedEMDeviceExcludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # Set policy specific settings depending on policy type
                        $PolicyType = $null
                        if ($Policy.'@odata.type' -like "*CompliancePolicy") {
                            $PolicyType = "Compliance"
                        }
                        else {
                            $PolicyType = "Configuration"
                        }
                        
                        # Create the policy and add to variable
                        $CreatedPolicy = $null
                        New-WTEMDevicePolicy @Parameters `
                            -EMDevicePolicies $Policy `
                            -PolicyType $PolicyType `
                            -NotificationMessageCCGroupId $NotificationGroupId `
                        | Tee-Object -Variable CreatedPolicy

                        # Adding an appropriate member id if supplied
                        if (${ENV:IncludeDeviceGroupID}) {
                            New-WTAzureADGroupRelationship @Parameters `
                                -Id $EMDeviceIncludeGroup.id `
                                -Relationship "members" `
                                -RelationshipIDs ${ENV:INCLUDEDEVICEGROUPID}
                        }

                        # Adding an appropriate member id if supplied
                        if (${ENV:ExcludeDeviceGroupID}) {
                            New-WTAzureADGroupRelationship @Parameters `
                                -Id $EMDeviceExcludeGroup.id `
                                -Relationship "members" `
                                -RelationshipIDs ${ENV:EXCLUDEDEVICEGROUPID}
                        }

                        # Create assignment relationship
                        New-WTEMDevicePolicyRelationship @Parameters `
                            -Id $CreatedPolicy.id `
                            -Relationship "assign" `
                            -PolicyType $PolicyType `
                            -IncludeAssignmentID $EMDeviceIncludeGroup.id `
                            -ExcludeAssignmentID $EMDeviceExcludeGroup.id
                    }
                    
                    # Export policies
                    Export-WTEMDevicePolicy -EMDevicePolicies $CreatedPolicies `
                        -Path $Path `
                        -ExcludeExportCleanup `
                        -DirectoryTag "ENV"

                    # Path to group config
                    $GroupsPath = $Path + "\..\..\Groups"
                    
                    # Export include groups
                    Export-WTAzureADGroup -AzureADGroups $EMDeviceIncludeGroups `
                        -Path $GroupsPath `
                        -ExcludeExportCleanup `
                        -DirectoryTag "ENV"

                    # Export exclude groups
                    Export-WTAzureADGroup -AzureADGroups $EMDeviceExcludeGroups `
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