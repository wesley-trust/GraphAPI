function Invoke-WTValidateRole {
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
            HelpMessage = "The Azure AD Roles to be validated if not imported from a JSON file"
        )]
        [Alias('Role', 'RoleDefinition')]
        [PSCustomObject]$DefinedRoles,
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
            $RequiredProperties = @("displayName","description","roleTemplateId")
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
                    $FilePath = (Get-ChildItem -Path $Path -Filter "*.json").FullName
                }
                else {
                    $ErrorMessage = "The provided path does not exist $Path, please check the path is correct"
                    throw $ErrorMessage
                }
            }

            # Import Roles from JSON file, if the files exist
            if ($FilePath) {
                $RoleImport = foreach ($File in $FilePath) {
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
                if ($RoleImport) {
                    $DefinedRoles = $RoleImport | ConvertFrom-Json
                }
                else {
                    $ErrorMessage = "No JSON files could be imported, please check the filepath is correct"
                    throw $ErrorMessage
                }
            }

            # If there are roles imported, run validation checks
            if ($DefinedRoles) {
                
                # Output current action
                Write-Host "Importing Defined Roles"
                Write-Host "Roles: $($DefinedRoles.count)"
                
                foreach ($Role in $DefinedRoles) {
                    if ($Role.displayName) {
                        Write-Host "Import: Role Name: $($Role.displayName)"
                    }
                    elseif ($Role.id) {
                        Write-Host "Import: Role Id: $($Role.id)"
                    }
                    else {
                        Write-Host "Import: Role Invalid"
                    }
                }

                # If import only is set, return roles without validating
                if ($ImportOnly) {
                    $DefinedRoles
                }
                else {
                        
                    # Output current action
                    Write-Host "Validating Defined Roles"
    
                    # For each policy, run validation checks
                    $InvalidRoles = foreach ($Role in $DefinedRoles) {
                        $RoleValidate = $null
    
                        # Check for missing properties
                        $RoleProperties = $null
                        $RoleProperties = ($Role | Get-Member -MemberType NoteProperty).name
                        $PropertyCheck = $null

                        # Check whether each required property, exists in the list of properties for the object
                        $PropertyCheck = foreach ($Property in $RequiredProperties) {
                            if ($Property -notIn $RoleProperties) {
                                $Property
                            }
                        }

                        # Check whether each required property has a value, if not, return property
                        $PropertyValueCheck = $null
                        $PropertyValueCheck = foreach ($Property in $RequiredProperties) {
                            if ($null -eq $Role.$Property) {
                                $Property
                            }
                        }
    
                        # Build and return object
                        if ($PropertyCheck -or $PropertyValueCheck) {
                            $RoleValidate = [ordered]@{}
                            if ($Role.displayName) {
                                $RoleValidate.Add("displayName", $Role.displayName)
                            }
                            elseif ($Role.id) {
                                $RoleValidate.Add("Id", $Role.id)
                            }
                        }
                        if ($PropertyCheck) {
                            $RoleValidate.Add("MissingProperties", $PropertyCheck)
                        }
                        if ($PropertyValueCheck) {
                            $RoleValidate.Add("MissingPropertyValues", $PropertyValueCheck)
                        }
                        if ($RoleValidate) {
                            [PSCustomObject]$RoleValidate
                        }
                    }

                    # Return validation result for each policy
                    if ($InvalidRoles) {
                        Write-Host "Invalid roles: $($InvalidRoles.count) out of $($DefinedRoles.count) imported"
                        foreach ($Role in $InvalidRoles) {
                            if ($Role.displayName) {
                                Write-Host "INVALID: Role Name: $($Role.displayName)" -ForegroundColor Yellow
                            }
                            elseif ($Role.id) {
                                Write-Host "INVALID: Role Id: $($Role.id)" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "INVALID: No displayName or Id for policy" -ForegroundColor Yellow
                            }
                            if ($Role.MissingProperties) {
                                Write-Warning "Required properties not present ($($Role.MissingProperties.count)): $($Role.MissingProperties)"
                            }
                            if ($Role.MissingPropertyValues) {
                                Write-Warning "Required property values not present ($($Role.MissingPropertyValues.count)): $($Role.MissingPropertyValues)"
                            }
                        }
    
                        # Abort import
                        $ErrorMessage = "Validation of roles was not successful, review configuration files and any warnings generated"
                        Write-Error $ErrorMessage
                        throw $ErrorMessage
                    }
                    else {

                        # Return validated roles
                        Write-Host "All roles have passed validation for required properties and values"
                        $ValidRoles = $DefinedRoles
                        $ValidRoles
                    }
                }
                
            }
            else {
                $ErrorMessage = "No Roles to be imported, import may have failed or none may exist"
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