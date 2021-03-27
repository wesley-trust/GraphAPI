function Invoke-WTAzureADNamedLocationImport {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with AzureAD Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with AzureAD Graph permissions"
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
            HelpMessage = "Specify whether to update existing named locations deployed in the tenant, where the IDs match"
        )]
        [switch]
        $UpdateExistingNamedLocations,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing named locations deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveExistingNamedLocations,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "If there are no named locations to import, whether to forcibly remove any existing named locations"
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
                "GraphAPI\Public\AzureAD\NamedLocations\Pipeline\Invoke-WTValidateAzureADNamedLocation.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\Pipeline\Invoke-WTPlanAzureADNamedLocation.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\Pipeline\Invoke-WTApplyAzureADNamedLocation.ps1"
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
            
                # Import and validate named locations
                Write-Host "Stage 1: Validate"
                Invoke-WTValidateAzureADNamedLocation @ValidateParameters | Tee-Object -Variable ValidateAzureADNamedLocations
            
                # If there are no named locations to import, but existing named locations should be removed, for safety, "Force" is required
                if (!$ValidateAzureADNamedLocations) {
                    if ($RemoveExistingNamedLocations -and !$Force) {
                        $ErrorMessage = "To continue, which will remove all existing named locations, use the switch -Force"
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
                    if ($ValidateAzureADNamedLocations) {
                        $PlanParameters.Add("AzureADNamedLocations", $ValidateAzureADNamedLocations)
                    }
                    if ($UpdateExistingNamedLocations) {
                        $PlanParameters.Add("UpdateExistingNamedLocations", $true)
                    }
                    if ($RemoveExistingNamedLocations) {
                        $PlanParameters.Add("RemoveExistingNamedLocations", $true)
                    }
                    if ($Force) {
                        $PlanParameters.Add("Force", $true)
                    }
                
                    # Create plan evaluating whether to create, update or remove named locations
                    Write-Host "Stage 2: Plan"
                    Invoke-WTPlanAzureADNamedLocation @PlanParameters | Tee-Object -Variable PlanAzureADNamedLocations

                }
                else {
                    $ErrorMessage = "No access token specified, obtain an access token object from Get-WTGraphAccessToken"
                    Write-Error $ErrorMessage
                    throw $ErrorMessage
                }

                if ($Stage -eq "Apply") {
                    if ($PlanAzureADNamedLocations) {
                        
                        # Build Parameters
                        $ApplyParameters = @{
                            AccessToken               = $AccessToken
                            AzureADNamedLocations = $PlanAzureADNamedLocations
                        }
                        if ($ExcludePreviewFeatures) {
                            $ApplyParameters.Add("ExcludePreviewFeatures", $true)
                        }
                        if ($UpdateExistingNamedLocations) {
                            $ApplyParameters.Add("UpdateExistingNamedLocations", $true)
                        }
                        if ($RemoveExistingNamedLocations) {
                            $ApplyParameters.Add("RemoveExistingNamedLocations", $true)
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
                        Invoke-WTApplyAzureADNamedLocation @ApplyParameters
                    }
                    else {
                        $WarningMessage = "No named locations will be created, updated or removed, as none exist that are different to the import"
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