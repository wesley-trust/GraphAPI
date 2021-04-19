function Get-WTAzureADSubscriptionDependency {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Azure AD subscription Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Azure AD subscription Graph permissions"
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Azure AD subscriptions to check for dependencies"
        )]
        [Alias("Subscription", "subscribedSkus")]
        [PSCustomObject]$Subscriptions,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $false,
            HelpMessage = "The Azure AD subscription service plan objects with dependencies"
        )]
        [Alias("ServicePlan")]
        [PSCustomObject]$ServicePlans,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $false,
            HelpMessage = "Specify whether to return the required ServicePlan or skuPartNumber instead of the default skuId of subscriptions with dependencies"
        )]
        [ValidateSet("ServicePlan", "SkuPartNumber", "SkuId")]
        [string]$DependencyType = "skuId"
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Get-WTAzureADSubscription.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Getting Azure AD Commercial Subscription Dependencies"

        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {
            
            # If there are no subscriptions, get all subscriptions
            if (!$Subscriptions) {
                
                # If there is no access token, obtain one
                if (!$AccessToken) {
                    $AccessToken = Get-WTGraphAccessToken `
                        -ClientID $ClientID `
                        -ClientSecret $ClientSecret `
                        -TenantDomain $TenantDomain
                }
                if ($AccessToken) {
                
                    # Build Parameters
                    $Parameters = @{
                        AccessToken = $AccessToken
                    }
                    if ($ExcludePreviewFeatures) {
                        $Parameters.Add("ExcludePreviewFeatures", $true)
                    }

                    # Get Azure AD subscriptions with default properties
                    $Subscriptions = Get-WTAzureADSubscription @Parameters
                }
                else {
                    $ErrorMessage = "No access token specified, obtain an access token object from Get-WTGraphAccessToken"
                    Write-Error $ErrorMessage
                    throw $ErrorMessage
                }
            }
            # Output current activity
            Write-Host $Activity
            if ($Subscriptions) {
                if ($ServicePlans) {

                    # Find subscriptions with dependencies
                    $DependentSubscriptionServicePlans = foreach ($Subscription in $Subscriptions) {
                        $RequiredServicePlans = $null
                        $RequiredServicePlans = foreach ($ServicePlan in $ServicePlans) {
                            if ($Subscription.servicePlans.servicePlanName -eq $ServicePlan.ServicePlanName) {
                                $ServicePlan.dependency.servicePlanName
                            }
                        }

                        # If there are dependencies, build object to return
                        if ($RequiredServicePlans) {
                            [PSCustomObject]@{
                                skuId                = $Subscription.skuId
                                skuPartNumber        = $Subscription.skuPartNumber
                                RequiredServicePlans = $RequiredServicePlans
                            }
                        }
                    }

                    # Find the skuPartNumbers with the dependent Service Plans for each subscription with dependencies
                    if ($DependencyType -eq "SkuPartNumber" -or $DependencyType -eq "SkuId") {
                        $DependentSubscriptionSkus = foreach ($DependentSubscription in $DependentSubscriptionServicePlans) {
                            $RequiredSkus = foreach ($Subscription in $Subscriptions) {
                                foreach ($DependentSubscriptionServicePlan in $DependentSubscription.RequiredServicePlans) {
                                    if ($DependentSubscriptionServicePlan -in $Subscription.servicePlans.servicePlanName) {
                                        $Subscription.$DependencyType
                                    }
                                }
                            }
                            
                            if ($RequiredSkus) {
                                [PSCustomObject]@{
                                    skuId                     = $DependentSubscription.skuId
                                    skuPartNumber             = $DependentSubscription.skuPartNumber
                                    "Required$DependencyType" = $RequiredSkus
                                }
                            }
                            else {
                                $WarningMessage = "There are no subscriptions with the required Service Plan dependencies"
                                Write-Warning $WarningMessage
                            }
                        }

                        # Return dependent subscription with required skuPartNumbers
                        if ($DependentSubscriptionSkus) {
                            $DependentSubscriptionSkus
                        }
                    }
                    elseif ($DependencyType -eq "servicePlan") {

                        # Return dependent subscription with required servicePlans
                        $DependentSubscriptionServicePlans
                    }
                }
                else {
                    $WarningMessage = "No Azure AD subscription service plans to check for dependencies"
                    Write-Warning $WarningMessage
                }
            }
            else {
                $WarningMessage = "No Azure AD subscriptions exist in Azure AD, or with parameters specified"
                Write-Warning $WarningMessage
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
