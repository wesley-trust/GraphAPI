function Invoke-WTValidateEMDevicePolicy {
    [CmdletBinding()]
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
            HelpMessage = "The Endpoint Manager Device Policies to be validated if not imported from a JSON file"
        )]
        [Alias('EMDevicePolicy', 'PolicyDefinition')]
        [PSCustomObject]$EMDevicePolicies,
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
            $RequiredProperties = @("displayName","@odata.type")
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

            # Import Device policies from JSON file, if the files exist
            if ($FilePath) {
                $EMDevicePolicyImport = foreach ($File in $FilePath) {
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
                if ($EMDevicePolicyImport) {
                    $EMDevicePolicies = $EMDevicePolicyImport | ConvertFrom-Json
                }
                else {
                    $ErrorMessage = "No JSON files could be imported, please check the filepath is correct"
                    throw $ErrorMessage
                }
            }

            # If there are policies imported, run validation checks
            if ($EMDevicePolicies) {
                
                # Output current action
                Write-Host "Importing Endpoint Manager Device Policies"
                Write-Host "Policies: $($EMDevicePolicies.count)"
                
                foreach ($Policy in $EMDevicePolicies) {
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
                    $EMDevicePolicies
                }
                else {
                        
                    # Output current action
                    Write-Host "Validating Endpoint Manager Device Policies"
    
                    # For each policy, run validation checks
                    $InvalidPolicies = foreach ($Policy in $EMDevicePolicies) {
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
                        if ($PolicyValidate) {
                            [PSCustomObject]$PolicyValidate
                        }
                    }

                    # Return validation result for each policy
                    if ($InvalidPolicies) {
                        Write-Host "Invalid Policies: $($InvalidPolicies.count) out of $($EMDevicePolicies.count) imported"
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
                        }
    
                        # Abort import
                        $ErrorMessage = "Validation of policies was not successful, review configuration files and any warnings generated"
                        Write-Error $ErrorMessage
                        throw $ErrorMessage
                    }
                    else {

                        # Return validated policies
                        Write-Host "All policies have passed validation for required properties and values"
                        $ValidPolicies = $EMDevicePolicies
                        $ValidPolicies
                    }
                }
                
            }
            else {
                $ErrorMessage = "No Device policies to be imported, import may have failed or none may exist"
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