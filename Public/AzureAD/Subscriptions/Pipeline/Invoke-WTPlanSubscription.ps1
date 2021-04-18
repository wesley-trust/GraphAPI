function Invoke-WTPlanSubscription {
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
            ValueFromPipeLine = $true,
            HelpMessage = "The Subscription object"
        )]
        [Alias("Subscription", "SubscriptionDefinition","Subscriptions")]
        [PSCustomObject]$DefinedSubscriptions,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether current Subscription deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveDefinedSubscriptions,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "If there are no Subscription to import, whether to forcibly remove any current Subscription"
        )]
        [switch]$Force
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Get-WTAzureADSubscription.ps1"
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
                Write-Host "Evaluating Subscriptions"
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # Get current enabled subscriptions for comparison
                $CurrentSubscriptions = Get-WTAzureADSubscription @Parameters
                $EnabledSubscriptions = $CurrentSubscriptions | Where-Object {
                    $_.capabilityStatus -eq "Enabled"
                }

                if ($DefinedSubscriptions) {

                    if ($EnabledSubscriptions) {

                        # Compare object on id and pass thru all objects, including those that exist and are to be imported
                        $SubscriptionComparison = Compare-Object `
                            -ReferenceObject $EnabledSubscriptions `
                            -DifferenceObject $DefinedSubscriptions `
                            -Property skuPartNumber `
                            -PassThru

                        # Filter for defined Subscription that should be removed, as they exist only in the import
                        $RemoveSubscriptions = $SubscriptionComparison | Where-Object { $_.sideindicator -eq "=>" }

                        # Filter for defined Subscription that should be created, as they exist only in Azure AD
                        $CreateSubscriptions = $SubscriptionComparison | Where-Object { $_.sideindicator -eq "<=" }
                    }
                    else {

                        # If force is enabled, then if removal of Subscription is specified, all current will be removed
                        if ($Force) {
                            $RemoveSubscriptions = $DefinedSubscriptions
                        }
                    }

                    if (!$RemoveDefinedSubscriptions) {

                        # If Subscription are not to be removed, disregard any Subscription for removal
                        $RemoveSubscriptions = $null
                    }
                }
                else {
                    
                    # If no defined subscription exist, any enabled subscriptions should be defined
                    $CreateSubscriptions = $EnabledSubscriptions
                }
                
                # Build object to return
                $PlanSubscriptions = [ordered]@{}

                if ($RemoveSubscriptions) {
                    $PlanSubscriptions.Add("RemoveSubscriptions", $RemoveSubscriptions)
                    
                    # Output current action
                    Write-Host "Subscription to remove: $($RemoveSubscriptions.count)"

                    foreach ($Subscription in $RemoveSubscriptions) {
                        Write-Host "Remove: Subscription ID: $($Subscription.id) (Subscription Groups will be removed as appropriate)" -ForegroundColor DarkRed
                    }
                }
                else {
                    Write-Host "No Subscription will be removed, as none exist that are different to the import"
                }
                if ($UpdateSubscriptions) {
                    $PlanSubscriptions.Add("UpdateSubscriptions", $UpdateSubscriptions)
                                        
                    # Output current action
                    Write-Host "Subscription to update: $($UpdateSubscriptions.count)"
                    
                    foreach ($Subscription in $UpdateSubscriptions) {
                        Write-Host "Update: Subscription ID: $($Subscription.id)" -ForegroundColor DarkYellow
                    }
                }
                else {
                    Write-Host "No Subscription will be updated, as none exist that are different to the import"
                }
                if ($CreateSubscriptions) {
                    $PlanSubscriptions.Add("CreateSubscriptions", $CreateSubscriptions)
                                        
                    # Output current action
                    Write-Host "Subscription to create: $($CreateSubscriptions.count) ( Groups will be created as appropriate)"

                    foreach ($Subscription in $CreateSubscriptions) {
                        Write-Host "Create: Subscription Name: $($Subscription.skuPartNumber)" -ForegroundColor DarkGreen
                    }
                }
                else {
                    Write-Host "No Subscription will be created, as none exist that are different to the import"
                }

                # If there are Subscription, return PS object
                if ($PlanSubscriptions) {
                    $PlanSubscriptions = [PSCustomObject]$PlanSubscriptions
                    $PlanSubscriptions
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