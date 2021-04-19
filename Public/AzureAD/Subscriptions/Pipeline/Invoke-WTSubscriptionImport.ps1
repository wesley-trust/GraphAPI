function Invoke-WTAzureADSubscriptionImport {
    [CmdletBinding()]
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
            HelpMessage = "The file path to the JSON file(s) that will be imported"
        )]
        [string[]]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory path(s) of which all JSON file(s) will be imported"
        )]
        [string]$Path,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory path to the location where the ServicePlan dependencies will be imported"
        )]
        [string]$DependentServicePlansPath,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether defined subscriptions deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveDefinedSubscriptions,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to the groups used for CA subscriptions, should not be removed, if the policy is removed"
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
            HelpMessage = "If there are no subscriptions to import, whether to forcibly remove any defined subscriptions"
        )]
        [switch]$Force,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify until what stage the import should invoke. All preceding stages will execute as dependencies"
        )]
        [ValidateSet("Validate", "Plan", "Apply")]
        [string]$Stage = "Apply",
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
                "GraphAPI\Public\AzureAD\Subscriptions\Pipeline\Invoke-WTValidateSubscription.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Pipeline\Invoke-WTPlanSubscription.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Pipeline\Invoke-WTApplySubscription.ps1"
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

            if ($Stage -eq "Validate" -or $Stage -eq "Plan" -or $Stage -eq "Apply") {
                
                # Build Parameters
                $ValidateParameters = @{}
                if ($ExcludePreviewFeatures) {
                    $ValidateParameters.Add("ExcludePreviewFeatures", $true)
                }
                if ($FilePath) {
                    $ValidateParameters.Add("FilePath", $FilePath)
                }
                elseif ($Path) {
                    $ValidateParameters.Add("Path", $Path)
                }
            
                # Import and validate subscriptions
                Write-Host "Stage 1: Validate"
                if ($FilePath -or $Path) {
                    $TestPath = Test-Path $Path -PathType Container
                    if ($TestPath -or $FilePath) {
                        Invoke-WTValidateSubscription @ValidateParameters | Tee-Object -Variable ValidateSubscriptions
                    }
                }
            }

            if ($Stage -eq "Plan" -or $Stage -eq "Apply") {

                # If there is no access token, obtain one
                if (!$AccessToken) {
                    $AccessToken = Get-WTGraphAccessToken `
                        -ClientID $ClientID `
                        -ClientSecret $ClientSecret `
                        -TenantDomain $TenantDomain
                }

                if ($AccessToken) {

                    # Build Parameters
                    $PlanParameters = @{
                        AccessToken = $AccessToken
                    }
                    if ($ExcludePreviewFeatures) {
                        $PlanParameters.Add("ExcludePreviewFeatures", $true)
                    }
                    if ($ValidateSubscriptions) {
                        $PlanParameters.Add("DefinedSubscriptions", $ValidateSubscriptions)
                    }
                    if ($RemoveDefinedSubscriptions) {
                        $PlanParameters.Add("RemoveDefinedSubscriptions", $true)
                    }
                    if ($Force) {
                        $PlanParameters.Add("Force", $true)
                    }
                
                    # Create plan evaluating whether to create, update or remove subscriptions
                    Write-Host "Stage 2: Plan"
                    Invoke-WTPlanSubscription @PlanParameters | Tee-Object -Variable PlanSubscriptions

                }
                else {
                    $ErrorMessage = "No access token specified, obtain an access token object from Get-WTGraphAccessToken"
                    Write-Error $ErrorMessage
                    throw $ErrorMessage
                }

                if ($Stage -eq "Apply") {
                    if ($PlanSubscriptions) {
                        
                        # Import service plan dependencies if they exist and convert from JSON
                        if ($DependentServicePlansPath) {
                            $PathExists = Test-Path -Path $DependentServicePlansPath
                            if ($PathExists) {
                                $DependentServicePlansFilePath = (Get-ChildItem -Path $DependentServicePlansPath -Filter "*.json").FullName
                            }
                            if ($DependentServicePlansFilePath) {
                                $DependentServicePlansImport = foreach ($DependentServicePlanFile in $DependentServicePlansFilePath) {
                                    Get-Content -Raw -Path $DependentServicePlanFile
                                }
                            }
                            if ($DependentServicePlansImport) {
                                $DependentServicePlans = $DependentServicePlansImport | ConvertFrom-Json -Depth 10
                            }
                        }

                        # Build Parameters
                        $ApplyParameters = @{
                            AccessToken          = $AccessToken
                            DefinedSubscriptions = $PlanSubscriptions
                        }
                        if ($ExcludePreviewFeatures) {
                            $ApplyParameters.Add("ExcludePreviewFeatures", $true)
                        }
                        if ($RemoveDefinedSubscriptions) {
                            $ApplyParameters.Add("RemoveDefinedSubscriptions", $true)
                        }
                        if ($ExcludeGroupRemoval) {
                            $ApplyParameters.Add("ExcludeGroupRemoval", $true)
                        }
                        if ($FilePath) {
                            $ApplyParameters.Add("FilePath", $FilePath)
                        }
                        elseif ($Path) {
                            $ApplyParameters.Add("Path", $Path)
                        }
                        if ($Pipeline) {
                            $ApplyParameters.Add("Pipeline", $true)
                        }
                        if ($DependentServicePlans) {
                            $ApplyParameters.Add("DependentServicePlans", $DependentServicePlans)
                        }

                        # Apply plan to Azure AD
                        Write-Host "Stage 3: Apply"
                        Invoke-WTApplySubscription @ApplyParameters
                    }
                    else {
                        $WarningMessage = "No subscriptions will be created, updated or removed, as none exist that are different to the import"
                        Write-Warning $WarningMessage
                    }
                }
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