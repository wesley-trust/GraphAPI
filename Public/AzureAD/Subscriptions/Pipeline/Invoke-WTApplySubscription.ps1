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
                "GraphAPI\Public\AzureAD\Subscriptions\Export-WTAzureADSubscription.ps1",
                "GraphAPI\Public\AzureAD\Groups\Export-WTAzureADGroup.ps1",
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
                        
                        # Remove subscription definition and groups
                        $SubscriptionSkuPartNumbers = $DefinedSubscriptions.RemoveSubscriptions.skuPartNumber
                        foreach ($SubscriptionSkuPartNumber in $SubscriptionSkuPartNumbers) {
                            Remove-Item -Path "$Path\$SubscriptionSkuPartNumber.json"
                        
                            # If the switch to not remove groups is not set, remove the groups for each Subscription also
                            if (!$ExcludeGroupRemoval) {

                                # Get, tag and identify the group for the subscription
                                $SubscriptionGroups = Get-WTAADSubscriptionGroup
                                $TaggedSubscriptionGroups = Invoke-WTPropertyTagging -Tags $Tag -QueryResponse $SubscriptionGroups -PropertyToTag $PropertyToTag
                                $SubscriptionGroups = $TaggedSubscriptionGroups | Where-Object {
                                    $_.$Tag -eq $SubscriptionSkuPartNumber
                                }

                                # Unique groups
                                $SubscriptionGroups = $SubscriptionGroups | Sort-Object -Unique

                                # If there are ids, pass all groups, which will perform a check and remove only subscription groups
                                if ($SubscriptionGroups) {
                                    
                                    # Remove licence from group if assigned
                                    if ($SubscriptionGroups.assignedLicenses) {
                                        Remove-WTAzureADGroupRelationship @Parameters `
                                            -Id $LicenceAssignedGroups.id `
                                            -Relationship "assignLicense" `
                                            -RelationshipIDs $SubscriptionGroups.assignedLicenses.skuid
                                    }
                                    
                                    # Remove group
                                    Remove-WTAADSubscriptionGroup @Parameters -IDs $SubscriptionGroups.id
                                                                            
                                    # Remove group config
                                    foreach ($SubscriptionGroup in $SubscriptionGroups) {
                                        Remove-Item -Path "$Path\Groups\$($SubscriptionGroup.displayName).json"
                                    }
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
                            
                            # Assign licence to group
                            New-WTAzureADGroupRelationship @Parameters `
                                -Id $SubscriptionGroup.id `
                                -Relationship "assignLicense" `
                                -RelationshipIDs $Subscription.skuId `
                                | Out-Null
                            
                            # Add member to group
                            if (${ENV:UserGroupID}) {
                                New-WTAzureADGroupRelationship @Parameters `
                                    -Id $SubscriptionGroup.id `
                                    -Relationship "members" `
                                    -RelationshipIDs ${ENV:USERGROUPID}
                            }
                        }
                    }

                    # Export subscriptions
                    Export-WTAzureADSubscription -DefinedSubscriptions $CreateSubscriptions `
                        -Path $Path `
                        -ExcludeExportCleanup

                    # Export groups
                    Export-WTAzureADGroup -AzureADGroups $SubscriptionGroups `
                        -Path "$Path\Groups" `
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