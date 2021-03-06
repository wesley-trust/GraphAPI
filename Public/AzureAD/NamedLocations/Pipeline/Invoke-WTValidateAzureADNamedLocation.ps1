function Invoke-WTValidateAzureADNamedLocation {
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
            HelpMessage = "The Azure AD Named Locations to be validated if not imported from a JSON file"
        )]
        [Alias('AzureADNamedLocation', 'LocationDefinition')]
        [PSCustomObject]$AzureADNamedLocations,
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
            $RequiredProperties = @("displayName", "countriesAndRegions")

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

            # Import groups from JSON file, if the files exist
            if ($FilePath) {
                $AzureADNamedLocationImport = foreach ($File in $FilePath) {
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
                if ($AzureADNamedLocationImport) {
                    $AzureADNamedLocations = $AzureADNamedLocationImport | ConvertFrom-Json
                }
                else {
                    $ErrorMessage = "No JSON files could be imported, please check the filepath is correct"
                    throw $ErrorMessage
                }
            }

            # If there are named locations imported, run validation checks
            if ($AzureADNamedLocations) {
                
                # Output current action
                Write-Host "Importing Azure AD Named Locations"
                Write-Host "Named Locations: $($AzureADNamedLocations.count)"
                
                foreach ($Location in $AzureADNamedLocations) {
                    if ($Location.displayName) {
                        Write-Host "Import: Named Location Name: $($Location.displayName)"
                    }
                    elseif ($Location.id) {
                        Write-Host "Import: Named Location Id: $($Location.id)"
                    }
                    else {
                        Write-Host "Import: Named Location Invalid"
                    }
                }

                # If import only is set, return named locations without validating
                if ($ImportOnly) {
                    $AzureADNamedLocations
                }
                else {
                        
                    # Output current action
                    Write-Host "Validating Azure AD Named Locations"
    
                    # For each group, run validation checks
                    $InvalidNamedLocations = foreach ($Location in $AzureADNamedLocations) {
                        $LocationValidate = $null
    
                        # Check for missing properties
                        $LocationProperties = $null
                        $LocationProperties = ($Location | Get-Member -MemberType NoteProperty).name
                        $PropertyCheck = $null

                        # Check whether each required property, exists in the list of properties for the object
                        $PropertyCheck = foreach ($Property in $RequiredProperties) {
                            if ($Property -notin $LocationProperties) {
                                $Property
                            }
                        }

                        # Check whether each required property has a value, if not, return property
                        $PropertyValueCheck = $null
                        $PropertyValueCheck = foreach ($Property in $RequiredProperties) {
                            if ($null -eq $Location.$Property) {
                                $Property
                            }
                        }

                        # Build and return object
                        if ($PropertyCheck -or $PropertyValueCheck) {
                            $LocationValidate = [ordered]@{}
                            if ($Location.displayName) {
                                $LocationValidate.Add("DisplayName", $Location.displayName)
                            }
                            elseif ($Location.id) {
                                $LocationValidate.Add("Id", $Location.id)
                            }
                        }
                        if ($PropertyCheck) {
                            $LocationValidate.Add("MissingProperties", $PropertyCheck)
                        }
                        if ($PropertyValueCheck) {
                            $LocationValidate.Add("MissingPropertyValues", $PropertyValueCheck)
                        }
                        if ($LocationValidate) {
                            [PSCustomObject]$LocationValidate
                        }
                    }

                    # Return validation result for each group
                    if ($InvalidNamedLocations) {
                        Write-Host "Invalid NamedLocations: $($InvalidNamedLocations.count) out of $($AzureADNamedLocations.count) imported"
                        foreach ($Location in $InvalidNamedLocations) {
                            if ($Location.displayName) {
                                Write-Host "INVALID: NamedLocation Name: $($Location.displayName)" -ForegroundColor Yellow
                            }
                            elseif ($Location.id) {
                                Write-Host "INVALID: NamedLocation Id: $($Location.id)" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "INVALID: No displayName or Id for group" -ForegroundColor Yellow
                            }
                            if ($Location.MissingProperties) {
                                Write-Warning "Required properties not present ($($Location.MissingProperties.count)): $($Location.MissingProperties)"
                            }
                            if ($Location.MissingPropertyValues) {
                                Write-Warning "Required property values not present ($($Location.MissingPropertyValues.count)): $($Location.MissingPropertyValues)"
                            }
                        }
    
                        # Abort import
                        $ErrorMessage = "Validation of named locations was not successful, review configuration files and any warnings generated"
                        Write-Error $ErrorMessage
                        throw $ErrorMessage
                    }
                    else {

                        # Return validated named locations
                        Write-Host "All named locations have passed validation for required properties and values"
                        $ValidNamedLocations = $AzureADNamedLocations
                        $ValidNamedLocations
                    }
                }
                
            }
            else {
                $ErrorMessage = "No Azure AD named locations to be imported, import may have failed or none may exist"
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