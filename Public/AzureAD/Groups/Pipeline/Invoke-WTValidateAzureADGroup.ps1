<#
.Synopsis
    Import all AzureAD groups from JSON definition and validate
.Description
    This function imports the AzureAD groups from JSON using the Microsoft Graph API and runs validation checks.
    The following Microsoft Graph API permissions are required for the service principal used for authentication:
        Group.ReadWrite.ConditionalAccess
        Group.Read.All
        Directory.Read.All
        Agreement.Read.All
        Application.Read.All
.PARAMETER ClientID
    Client ID for the Azure AD service principal with AzureAD Graph permissions
.PARAMETER ClientSecret
    Client secret for the Azure AD service principal with AzureAD Graph permissions
.PARAMETER TenantName
    The initial domain (onmicrosoft.com) of the tenant
.PARAMETER AccessToken
    The access token, obtained from executing Get-WTGraphAccessToken
.PARAMETER FilePath
    The file path to the JSON file that will be imported
.PARAMETER GroupState
    Modify the group state when imported, when not specified the group will maintain state
.PARAMETER RemoveAllExistingGroups
    Specify whether all existing groups deployed in the tenant will be removed
.PARAMETER ExcludePreviewFeatures
    Specify whether to exclude features in preview, a production API version will then be used instead
.INPUTS
    JSON file with all AzureAD groups
.OUTPUTS
    None
.NOTES

.Example
    $Parameters = @{
                ClientID = ""
                ClientSecret = ""
                TenantDomain = ""
                FilePath = ""
    }
    Import-WTAzureADGroup.ps1 @Parameters
    Import-WTAzureADGroup.ps1 -AccessToken $AccessToken -FilePath ""
#>

function Invoke-WTValidateAzureADGroup {
    [cmdletbinding()]
    param (
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
            HelpMessage = "Specify whether files should be imported only, and not validated"
        )]
        [switch]$ImportOnly
    )
    Begin {
        try {
            # Variables
            $RequiredProperties = @("displayName", "grantControls", "conditions", "state", "sessionControls")
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # For each directory, get the file path of all JSON files within the directory, if the directory exists
            if ($Path) {
                $PathExists = Test-Path -Path $Path
                if ($PathExists) {
                    $FilePath = foreach ($Directory in $Path) {
                        (Get-ChildItem -Path $Directory -Filter "*.json" -Recurse).FullName
                    }
                }
            }

            # Import groups from JSON file
            if ($FilePath) {
                $AzureADGroups = foreach ($File in $FilePath) {
                    Get-Content -Raw -Path $File
                }
            }

            # If a file has been imported, convert from JSON to an object for deployment
            if ($AzureADGroups) {

                $AzureADGroups = $AzureADGroups | ConvertFrom-Json
                
                # Output current action
                Write-Host "Importing Azure AD Groups"
                Write-Host "Groups: $($AzureADGroups.count)"
                
                foreach ($Group in $AzureADGroups) {
                    if ($Group.displayName) {
                        Write-Host "Import: Group Name: $($Group.displayName)"
                    }
                    elseif ($Group.id) {
                        Write-Host "Import: Group Id: $($Group.id)"
                    }
                    else {
                        Write-Host "Import: Group Invalid"
                    }
                }

                # If there are groups imported, run validation checks
                if ($AzureADGroups) {

                    # If import only is set, return groups without validating
                    if ($ImportOnly) {
                        $AzureADGroups
                    }
                    else {
                        
                        # Output current action
                        Write-Host "Validating Azure AD Groups"
    
                        # For each group, run validation checks
                        $InvalidGroups = foreach ($Group in $AzureADGroups) {
                            $GroupValidate = $null
    
                            # Check for missing properties
                            $GroupProperties = $null
                            $GroupProperties = ($Group | Get-Member -MemberType NoteProperty).name
                            $PropertyCheck = $null

                            # Check whether each required property, exists in the list of properties for the object
                            $PropertyCheck = foreach ($Property in $RequiredProperties) {
                                if ($Property -notin $GroupProperties) {
                                    $Property
                                }
                            }

                            # Check for missing grant or session controls
                            $ControlsCheck = $null
                            $ControlsCheck = if (!$Group.GrantControls) {
                                if (!$Group.sessioncontrols) {
                                    Write-Output "No grant or session controls specified, at least one must be specified"
                                }
                            }

                            # Check for missing conditions (under applications)
                            $ApplicationsProperties = $null
                            $ApplicationsProperties = ($Group.conditions.applications | Get-Member -MemberType NoteProperty).name
                            $ConditionsCheck = $null

                            # For each condition, return true if a value exists for each condition checked
                            $ConditionsCheck = foreach ($Condition in $ApplicationsProperties) {
                                if ($Group.conditions.applications.$Condition) {
                                    $true
                                }
                            }
    
                            # If true is not in the condition check variable, it means there were no conditions that had a value
                            if ($true -notin $ConditionsCheck) {
                                $ConditionsCheck = Write-Output "No application conditions specified, at least one must be specified"
                            }
                            else {
                                $ConditionsCheck = $null
                            }

                            # Build and return object
                            if ($PropertyCheck -or $ControlsCheck -or $ConditionsCheck) {
                                $GroupValidate = [ordered]@{}
                                if ($Group.displayName) {
                                    $GroupValidate.Add("DisplayName", $Group.displayName)
                                }
                                elseif ($Group.id) {
                                    $GroupValidate.Add("Id", $Group.id)
                                }
                            }
                            if ($PropertyCheck) {
                                $GroupValidate.Add("MissingProperties", $PropertyCheck)
                            }
                            if ($ControlsCheck) {
                                $GroupValidate.Add("MissingControls", $ControlsCheck)
                            }
                            if ($ConditionsCheck) {
                                $GroupValidate.Add("MissingConditions", $ConditionsCheck)
                            }
                            if ($GroupValidate) {
                                [pscustomobject]$GroupValidate
                            }
                        }

                        # Return validation result for each group
                        if ($InvalidGroups) {
                            Write-Host "Invalid Groups: $($InvalidGroups.count) out of $($AzureADGroups.count) imported"
                            foreach ($Group in $InvalidGroups) {
                                if ($Group.displayName) {
                                    Write-Host "INVALID: Group Name: $($Group.displayName)" -ForegroundColor Yellow
                                }
                                elseif ($Group.id) {
                                    Write-Host "INVALID: Group Id: $($Group.id)" -ForegroundColor Yellow
                                }
                                else {
                                    Write-Host "INVALID: No displayName or Id for group" -ForegroundColor Yellow
                                }
                                if ($Group.MissingProperties) {
                                    Write-Warning "Required properties not present ($($Group.MissingProperties.count)): $($Group.MissingProperties)"
                                }
                                if ($Group.MissingControls) {
                                    Write-Warning "$($Group.MissingControls)"
                                }
                                if ($Group.MissingConditions) {
                                    Write-Warning "$($Group.MissingConditions)"
                                }
                            }
    
                            # Abort import
                            $ErrorMessage = "Validation of groups was not successful, review configuration files and any warnings generated"
                            Write-Error $ErrorMessage
                            throw $ErrorMessage
                        }
                        else {

                            # Return validated groups
                            Write-Host "All groups have passed validation for required properties, controls and conditions"
                            $ValidGroups = $AzureADGroups
                            $ValidGroups
                        }
                    }
                }
                else {
                    $WarningMessage = "No Azure AD groups to be imported, import may have failed or none may exist"
                    Write-Warning $WarningMessage
                }
            }
            else {
                $WarningMessage = "No Azure AD groups to be imported, import may have failed or none may exist"
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