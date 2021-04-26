function Invoke-WTValidateSubscription {
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
            HelpMessage = "The Azure AD Subscriptions to be validated if not imported from a JSON file"
        )]
        [Alias('Subscription', 'SubscriptionDefinition')]
        [PSCustomObject]$DefinedSubscriptions,
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
            $RequiredProperties = @("skuPartNumber","skuId","servicePlans","capabilityStatus","appliesTo")
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

            # Import Subscriptions from JSON file, if the files exist
            if ($FilePath) {
                $SubscriptionImport = foreach ($File in $FilePath) {
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
                if ($SubscriptionImport) {
                    $DefinedSubscriptions = $SubscriptionImport | ConvertFrom-Json
                }
                else {
                    $ErrorMessage = "No JSON files could be imported, please check the filepath is correct"
                    throw $ErrorMessage
                }
            }

            # If there are subscriptions imported, run validation checks
            if ($DefinedSubscriptions) {
                
                # Output current action
                Write-Host "Importing Defined Subscriptions"
                Write-Host "Subscriptions: $($DefinedSubscriptions.count)"
                
                foreach ($Subscription in $DefinedSubscriptions) {
                    if ($Subscription.skuPartNumber) {
                        Write-Host "Import: Subscription Name: $($Subscription.skuPartNumber)"
                    }
                    elseif ($Subscription.id) {
                        Write-Host "Import: Subscription Id: $($Subscription.id)"
                    }
                    else {
                        Write-Host "Import: Subscription Invalid"
                    }
                }

                # If import only is set, return subscriptions without validating
                if ($ImportOnly) {
                    $DefinedSubscriptions
                }
                else {
                        
                    # Output current action
                    Write-Host "Validating Defined Subscriptions"
    
                    # For each policy, run validation checks
                    $InvalidSubscriptions = foreach ($Subscription in $DefinedSubscriptions) {
                        $SubscriptionValidate = $null
    
                        # Check for missing properties
                        $SubscriptionProperties = $null
                        $SubscriptionProperties = ($Subscription | Get-Member -MemberType NoteProperty).name
                        $PropertyCheck = $null

                        # Check whether each required property, exists in the list of properties for the object
                        $PropertyCheck = foreach ($Property in $RequiredProperties) {
                            if ($Property -notin $SubscriptionProperties) {
                                $Property
                            }
                        }

                        # Check whether each required property has a value, if not, return property
                        $PropertyValueCheck = $null
                        $PropertyValueCheck = foreach ($Property in $RequiredProperties) {
                            if ($null -eq $Subscription.$Property) {
                                $Property
                            }
                        }
    
                        # Build and return object
                        if ($PropertyCheck -or $PropertyValueCheck) {
                            $SubscriptionValidate = [ordered]@{}
                            if ($Subscription.skuPartNumber) {
                                $SubscriptionValidate.Add("skuPartNumber", $Subscription.skuPartNumber)
                            }
                            elseif ($Subscription.id) {
                                $SubscriptionValidate.Add("Id", $Subscription.id)
                            }
                        }
                        if ($PropertyCheck) {
                            $SubscriptionValidate.Add("MissingProperties", $PropertyCheck)
                        }
                        if ($PropertyValueCheck) {
                            $SubscriptionValidate.Add("MissingPropertyValues", $PropertyValueCheck)
                        }
                        if ($SubscriptionValidate) {
                            [PSCustomObject]$SubscriptionValidate
                        }
                    }

                    # Return validation result for each policy
                    if ($InvalidSubscriptions) {
                        Write-Host "Invalid subscriptions: $($InvalidSubscriptions.count) out of $($DefinedSubscriptions.count) imported"
                        foreach ($Subscription in $InvalidSubscriptions) {
                            if ($Subscription.skuPartNumber) {
                                Write-Host "INVALID: Subscription Name: $($Subscription.skuPartNumber)" -ForegroundColor Yellow
                            }
                            elseif ($Subscription.id) {
                                Write-Host "INVALID: Subscription Id: $($Subscription.id)" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "INVALID: No skuPartNumber or Id for policy" -ForegroundColor Yellow
                            }
                            if ($Subscription.MissingProperties) {
                                Write-Warning "Required properties not present ($($Subscription.MissingProperties.count)): $($Subscription.MissingProperties)"
                            }
                            if ($Subscription.MissingPropertyValues) {
                                Write-Warning "Required property values not present ($($Subscription.MissingPropertyValues.count)): $($Subscription.MissingPropertyValues)"
                            }
                        }
    
                        # Abort import
                        $ErrorMessage = "Validation of subscriptions was not successful, review configuration files and any warnings generated"
                        Write-Error $ErrorMessage
                        throw $ErrorMessage
                    }
                    else {

                        # Return validated subscriptions
                        Write-Host "All subscriptions have passed validation for required properties and values"
                        $ValidSubscriptions = $DefinedSubscriptions
                        $ValidSubscriptions
                    }
                }
                
            }
            else {
                $ErrorMessage = "No Subscriptions to be imported, import may have failed or none may exist"
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