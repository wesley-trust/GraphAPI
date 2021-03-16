function Invoke-WTCAPolicyImport {
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
            HelpMessage = "The file path to the JSON file(s) that will be imported"
        )]
        [string[]]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory path(s) of which all JSON file(s) will be imported"
        )]
        [string]$Path,
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
            HelpMessage = "If there are no policies to import, whether to forcibly remove any existing policies"
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
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Pipeline\Invoke-WTValidateCAPolicy.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Pipeline\Invoke-WTPlanCAPolicy.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Pipeline\Invoke-WTApplyCAPolicy.ps1"
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
            
                # Import and validate policies
                Write-Host "Stage 1: Validate"
                Invoke-WTValidateCAPolicy @ValidateParameters | Tee-Object -Variable ValidateCAPolicies
            
                # If there are no policies to import, but existing policies should be removed, for safety, "Force" is required
                if (!$ValidateCAPolicies) {
                    if ($RemoveExistingPolicies -and !$Force) {
                        $ErrorMessage = "To continue, which will remove all existing policies, use the switch -Force"
                        throw $ErrorMessage
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
                    if ($ValidateCAPolicies) {
                        $PlanParameters.Add("ConditionalAccessPolicies", $ValidateCAPolicies)
                    }
                    if ($UpdateExistingPolicies) {
                        $PlanParameters.Add("UpdateExistingPolicies", $true)
                    }
                    if ($RemoveExistingPolicies) {
                        $PlanParameters.Add("RemoveExistingPolicies", $true)
                    }
                    if ($Force) {
                        $PlanParameters.Add("Force", $true)
                    }
                
                    # Create plan evaluating whether to create, update or remove policies
                    Write-Host "Stage 2: Plan"
                    Invoke-WTPlanCAPolicy @PlanParameters | Tee-Object -Variable PlanCAPolicies

                }
                else {
                    $ErrorMessage = "No access token specified, obtain an access token object from Get-WTGraphAccessToken"
                    Write-Error $ErrorMessage
                    throw $ErrorMessage
                }

                if ($Stage -eq "Apply") {
                    if ($PlanCAPolicies) {
                        
                        # Build Parameters
                        $ApplyParameters = @{
                            AccessToken               = $AccessToken
                            ConditionalAccessPolicies = $PlanCAPolicies
                        }
                        if ($ExcludePreviewFeatures) {
                            $ApplyParameters.Add("ExcludePreviewFeatures", $true)
                        }
                        if ($UpdateExistingPolicies) {
                            $ApplyParameters.Add("UpdateExistingPolicies", $true)
                        }
                        if ($RemoveExistingPolicies) {
                            $ApplyParameters.Add("RemoveExistingPolicies", $true)
                        }
                        if ($ExcludeGroupRemoval) {
                            $ApplyParameters.Add("ExcludeGroupRemoval", $true)
                        }
                        if ($PolicyState) {
                            $ApplyParameters.Add("PolicyState", $PolicyState)
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
                    
                        # Apply plan to Azure AD
                        Write-Host "Stage 3: Apply"
                        Invoke-WTApplyCAPolicy @ApplyParameters
                    }
                    else {
                        $WarningMessage = "No policies will be created, updated or removed, as none exist that are different to the import"
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
        
    }
}