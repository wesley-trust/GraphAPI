function Invoke-WTValidateCAPolicy {
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
            ValueFromPipeLine = $true,
            HelpMessage = "The Azure AD Conditional Access Policies to be validated if not imported from a JSON file"
        )]
        [Alias('ConditionalAccessPolicy', 'PolicyDefinition')]
        [PSCustomObject]$ConditionalAccessPolicies,
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
            $RequiredProperties = @("displayName", "conditions", "state")
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
                    $FilePath = (Get-ChildItem -Path $Path -Filter "*.json" -Recurse).FullName
                }
                else {
                    $ErrorMessage = "The provided path does not exist $Path, please check the path is correct"
                    throw $ErrorMessage
                }
            }

            # Import Conditional Access policies from JSON file, if the files exist
            if ($FilePath) {
                $ConditionalAccessPolicyImport = foreach ($File in $FilePath) {
                    $FilePathExists = Test-Path -Path $File
                    if ($FilePathExists) {
                        Get-Content -Raw -Path $File
                    }
                    else {
                        $ErrorMessage = "The provided filepath $File does not exist, please check the path is correct"
                        throw $ErrorMessage
                    }
                }
                
                # If import was successful, convert from JSON
                if ($ConditionalAccessPolicyImport) {
                    $ConditionalAccessPolicies = $ConditionalAccessPolicyImport | ConvertFrom-Json
                }
                else {
                    $ErrorMessage = "No JSON files could be imported, please check the filepath is correct"
                    throw $ErrorMessage
                }
            }

            # If there are policies imported, run validation checks
            if ($ConditionalAccessPolicies) {
                
                # Output current action
                Write-Host "Importing Conditional Access Policies"
                Write-Host "Policies: $($ConditionalAccessPolicies.count)"
                
                foreach ($Policy in $ConditionalAccessPolicies) {
                    if ($Policy.displayName) {
                        Write-Host "Import: Policy Name: $($Policy.displayName)"
                    }
                    elseif ($Policy.id) {
                        Write-Host "Import: Policy Id: $($Policy.id)"
                    }
                    else {
                        Write-Host "Import: Policy Invalid"
                    }
                }

                # If import only is set, return policies without validating
                if ($ImportOnly) {
                    $ConditionalAccessPolicies
                }
                else {
                        
                    # Output current action
                    Write-Host "Validating Conditional Access Policies"
    
                    # For each policy, run validation checks
                    $InvalidPolicies = foreach ($Policy in $ConditionalAccessPolicies) {
                        $PolicyValidate = $null
    
                        # Check for missing properties
                        $PolicyProperties = $null
                        $PolicyProperties = ($Policy | Get-Member -MemberType NoteProperty).name
                        $PropertyCheck = $null

                        # Check whether each required property, exists in the list of properties for the object
                        $PropertyCheck = foreach ($Property in $RequiredProperties) {
                            if ($Property -notin $PolicyProperties) {
                                $Property
                            }
                        }

                        # Check whether each required property has a value, if not, return property
                        $PropertyValueCheck = $null
                        $PropertyValueCheck = foreach ($Property in $RequiredProperties) {
                            if ($null -eq $Policy.$Property) {
                                $Property
                            }
                        }

                        # Check for missing grant or session controls
                        $ControlsCheck = $null
                        $ControlsCheck = if (!$Policy.GrantControls) {
                            if (!$Policy.sessionControls) {
                                Write-Output "No grant or session controls specified, at least one must be specified"
                            }
                        }

                        # Check for missing conditions (under applications)
                        $ApplicationsProperties = $null
                        $ApplicationsProperties = ($Policy.conditions.applications | Get-Member -MemberType NoteProperty).name
                        $ConditionsCheck = $null

                        # For each condition, return true if a value exists for each condition checked
                        $ConditionsCheck = foreach ($Condition in $ApplicationsProperties) {
                            if ($Policy.conditions.applications.$Condition) {
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
                            $PolicyValidate = [ordered]@{}
                            if ($Policy.displayName) {
                                $PolicyValidate.Add("DisplayName", $Policy.displayName)
                            }
                            elseif ($Policy.id) {
                                $PolicyValidate.Add("Id", $Policy.id)
                            }
                        }
                        if ($PropertyCheck) {
                            $PolicyValidate.Add("MissingProperties", $PropertyCheck)
                        }
                        if ($PropertyValueCheck) {
                            $PolicyValidate.Add("MissingPropertyValues", $PropertyValueCheck)
                        }
                        if ($ControlsCheck) {
                            $PolicyValidate.Add("MissingControls", $ControlsCheck)
                        }
                        if ($ConditionsCheck) {
                            $PolicyValidate.Add("MissingConditions", $ConditionsCheck)
                        }
                        if ($PolicyValidate) {
                            [pscustomobject]$PolicyValidate
                        }
                    }

                    # Return validation result for each policy
                    if ($InvalidPolicies) {
                        Write-Host "Invalid Policies: $($InvalidPolicies.count) out of $($ConditionalAccessPolicies.count) imported"
                        foreach ($Policy in $InvalidPolicies) {
                            if ($Policy.displayName) {
                                Write-Host "INVALID: Policy Name: $($Policy.displayName)" -ForegroundColor Yellow
                            }
                            elseif ($Policy.id) {
                                Write-Host "INVALID: Policy Id: $($Policy.id)" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "INVALID: No displayName or Id for policy" -ForegroundColor Yellow
                            }
                            if ($Policy.MissingProperties) {
                                Write-Warning "Required properties not present ($($Policy.MissingProperties.count)): $($Policy.MissingProperties)"
                            }
                            if ($Policy.MissingPropertyValues) {
                                Write-Warning "Required property values not present ($($Policy.MissingPropertyValues.count)): $($Policy.MissingPropertyValues)"
                            }
                            if ($Policy.MissingControls) {
                                Write-Warning "$($Policy.MissingControls)"
                            }
                            if ($Policy.MissingConditions) {
                                Write-Warning "$($Policy.MissingConditions)"
                            }
                        }
    
                        # Abort import
                        $ErrorMessage = "Validation of policies was not successful, review configuration files and any warnings generated"
                        Write-Error $ErrorMessage
                        throw $ErrorMessage
                    }
                    else {

                        # Return validated policies
                        Write-Host "All policies have passed validation for required properties, values, controls and conditions"
                        $ValidPolicies = $ConditionalAccessPolicies
                        $ValidPolicies
                    }
                }
                
            }
            else {
                $ErrorMessage = "No Conditional Access policies to be imported, import may have failed or none may exist"
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