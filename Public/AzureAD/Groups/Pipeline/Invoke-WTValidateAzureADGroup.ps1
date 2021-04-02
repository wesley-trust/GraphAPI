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
            ValueFromPipe = $true,
            HelpMessage = "The Azure AD Groups to be validated if not imported from a JSON file"
        )]
        [Alias('AzureADGroup', 'GroupDefinition')]
        [PSCustomObject]$AzureADGroups,
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
            $RequiredProperties = @("displayName", "mailEnabled", "securityEnabled")

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
                    if (!$FilePath) {
                        $ErrorMessage = "No JSON files were found in the location specified $Path, please check the path is correct"
                        throw $ErrorMessage
                    }
                }
                else {
                    $ErrorMessage = "The provided path does not exist $Path, please check the path is correct"
                    throw $ErrorMessage
                }
            }

            # Import groups from JSON file, if the files exist
            if ($FilePath) {
                $AzureADGroupImport = foreach ($File in $FilePath) {
                    $FilePathExists = $null
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
                if ($AzureADGroupImport) {
                    $AzureADGroups = $AzureADGroupImport | ConvertFrom-Json
                }
                else {
                    $ErrorMessage = "No JSON files could be imported, please check the filepath is correct"
                    throw $ErrorMessage
                }
            }

            # If a file has been imported, or objects provided in the parameter
            if ($AzureADGroups) {
                
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

                        # Check whether each required property has a value, if not, return property
                        $PropertyValueCheck = $null
                        $PropertyValueCheck = foreach ($Property in $RequiredProperties) {
                            if ($null -eq $Group.$Property) {
                                $Property
                            }
                        }

                        # Build and return object
                        if ($PropertyCheck -or $PropertyValueCheck) {
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
                        if ($PropertyValueCheck) {
                            $GroupValidate.Add("MissingPropertyValues", $PropertyValueCheck)
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
                            if ($Group.MissingPropertyValues) {
                                Write-Warning "Required property values not present ($($Group.MissingPropertyValues.count)): $($Group.MissingPropertyValues)"
                            }
                        }
    
                        # Abort import
                        $ErrorMessage = "Validation of groups was not successful, review configuration files and any warnings generated"
                        throw $ErrorMessage
                    }
                    else {

                        # Return validated groups
                        Write-Host "All groups have passed validation for required properties and values"
                        $ValidGroups = $AzureADGroups
                        $ValidGroups
                    }
                }
                
            }
            else {
                $ErrorMessage = "No Azure AD groups to be imported, import may have failed or none may exist"
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