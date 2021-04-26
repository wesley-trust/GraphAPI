function Invoke-WTApplySubscription {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Subscription Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Subscription Graph permissions"
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
            HelpMessage = "The Subscription object"
        )]
        [Alias("Subscription", "SubscriptionDefinition", "Subscriptions")]
        [PSCustomObject]$DefinedSubscriptions,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The dependent service plan objects"
        )]
        [Alias("ServicePlan", "ServicePlans", "DependentServicePlan")]
        [PSCustomObject]$DependentServicePlans,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing subscriptions deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveDefinedSubscriptions,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to the groups used for subscriptions, should not be removed, if the subscription is removed"
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
                "GraphAPI\Public\AzureAD\Subscriptions\Groups\Get-WTAADSubscriptionGroup.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Groups\New-WTAADSubscriptionGroup.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Groups\Remove-WTAADSubscriptionGroup.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Get-WTAzureADSubscriptionDependency.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Export-WTAzureADSubscription.ps1",
                "GraphAPI\Public\AzureAD\Groups\Export-WTAzureADGroup.ps1",
                "GraphAPI\Public\AzureAD\Groups\Relationship\Get-WTAzureADGroupRelationship.ps1",
                "GraphAPI\Public\AzureAD\Groups\Relationship\New-WTAzureADGroupRelationship.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Tag = "SKU"
            $PropertyToTag = "displayName"
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
                Write-Host "Deploying Subscriptions"

                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                if ($RemoveDefinedSubscriptions) {

                    # If subscriptions require removing, pass the ids to the remove function
                    if ($DefinedSubscriptions.RemoveSubscriptions) {
                        
                        # Get and tag group for the subscriptions
                        $SubscriptionGroups = Get-WTAADSubscriptionGroup
                        $TaggedSubscriptionGroups = Invoke-WTPropertyTagging -Tags $Tag -QueryResponse $SubscriptionGroups -PropertyToTag $PropertyToTag

                        # Path to group config
                        $GroupsPath = $Path + "\..\Groups"

                        # Remove subscription definition and groups
                        $SubscriptionSkuPartNumbers = $DefinedSubscriptions.RemoveSubscriptions.skuPartNumber
                        foreach ($SubscriptionSkuPartNumber in $SubscriptionSkuPartNumbers) {
                            Remove-Item -Path "$Path\$SubscriptionSkuPartNumber.json"
                        
                            # If the switch to not remove groups is not set, remove the groups for each Subscription also
                            if (!$ExcludeGroupRemoval) {

                                # Identify the group for the subscription
                                $SubscriptionGroup = $null
                                $SubscriptionGroup = $TaggedSubscriptionGroups | Where-Object {
                                    $_.$Tag -eq $SubscriptionSkuPartNumber
                                }

                                # If there is a group, pass the id which will perform a check and remove only subscription groups
                                if ($SubscriptionGroup) {
                                    
                                    # Remove group (licences should no longer be assigned to deleted subscriptions)
                                    Remove-WTAADSubscriptionGroup @Parameters -IDs $SubscriptionGroup.id

                                    # Remove group config
                                    Remove-Item -Path "$GroupsPath\$($SubscriptionGroup.displayName).json"
                                }
                            }
                        }
                    }
                    else {
                        $WarningMessage = "No subscriptions will be removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }

                # If there are new subscriptions create the groups
                if ($DefinedSubscriptions.CreateSubscriptions) {
                    $CreateSubscriptions = $DefinedSubscriptions.CreateSubscriptions

                    # Find subscriptions with service plan dependencies
                    if ($DependentServicePlans) {
                        $DependentSubscriptions = Get-WTAzureADSubscriptionDependency @Parameters `
                            -Subscriptions $CreateSubscriptions `
                            -ServicePlans $DependentServicePlans `
                            -DependencyType SkuId
                    }

                    # Calculate the display names to be used for the Subscription groups
                    $SubscriptionGroupDisplayName = foreach ($Subscription in $CreateSubscriptions) {
                        "$Tag" + "-" + $Subscription.skuPartNumber + ";"
                    }

                    # Create groups
                    $SubscriptionGroups = New-WTAADSubscriptionGroup @Parameters -DisplayName $SubscriptionGroupDisplayName

                    # Tag groups
                    $TaggedSubscriptionGroups = Invoke-WTPropertyTagging -Tags $Tag -QueryResponse $SubscriptionGroups -PropertyToTag $PropertyToTag

                    # For each subscription, perform subscription specific changes
                    foreach ($Subscription in $CreateSubscriptions) {

                        # Find the matching group
                        $SubscriptionGroup = $null
                        $SubscriptionGroup = $TaggedSubscriptionGroups | Where-Object {
                            $_.$Tag -eq $Subscription.skuPartNumber
                        }

                        # If there is a group for this subscription (as subscriptions may not always have groups)
                        if ($SubscriptionGroup) {
                            
                            # If this subscription is in the list of dependent subscriptions
                            if ($Subscription.skuId -in $DependentSubscriptions.skuId) {
                                
                                # Filter to the specific subscription dependency
                                $DependentSubscription = $null
                                $DependentSubscription = $DependentSubscriptions | Where-Object {
                                    $_.skuId -eq $Subscription.skuId
                                }

                                # Assign each required sku for the dependent subscription
                                foreach ($SkuId in $DependentSubscription.RequiredSkuId) {
                                    New-WTAzureADGroupRelationship @Parameters `
                                        -Id $SubscriptionGroup.id `
                                        -Relationship "assignLicense" `
                                        -RelationshipIDs $SkuId `
                                    | Out-Null
                                }
                            }

                            # Assign licence to group
                            New-WTAzureADGroupRelationship @Parameters `
                                -Id $SubscriptionGroup.id `
                                -Relationship "assignLicense" `
                                -RelationshipIDs $Subscription.skuId `
                            | Out-Null
                            
                            # Workaround lack of nested group support, by getting users that should be licenced
                            if (${ENV:UserGroupID}) {
                                $Members = Get-WTAzureADGroupRelationship @Parameters `
                                    -Id ${ENV:UserGroupID} `
                                    -Relationship "members"
                                
                                # Then adding the users that should be licenced directly to the group
                                if ($Members) {
                                    New-WTAzureADGroupRelationship @Parameters `
                                        -Id $SubscriptionGroup.id `
                                        -Relationship "members" `
                                        -RelationshipIDs $Members.id
                                }
                            }
                        }
                    }

                    # Export subscriptions
                    Export-WTAzureADSubscription -DefinedSubscriptions $CreateSubscriptions `
                        -Path $Path `
                        -ExcludeExportCleanup

                    # Path to group config
                    $GroupsPath = $Path + "\..\Groups"

                    # Export groups
                    Export-WTAzureADGroup -AzureADGroups $SubscriptionGroups `
                        -Path $GroupsPath `
                        -ExcludeExportCleanup `
                        -ExcludeTagEvaluation

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
                    $WarningMessage = "No subscriptions will be created, as none exist that are different to the import"
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