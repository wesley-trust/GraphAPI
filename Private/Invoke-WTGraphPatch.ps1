function Invoke-WTGraphPatch {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The access token, obtained from executing Get-WTGraphAccessToken"
        )]
        [string]$AccessToken,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The objects to be patched"
        )]
        [pscustomobject]$InputObject,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The uniform resource indicator"
        )]
        [string]$Uri,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The activity being performed"
        )]
        [string]$Activity,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Properties that may exist that need to be removed prior to creation"
        )]
        [string[]]$CleanUpProperties
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Private\Invoke-WTGraphQuery.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Method = "Patch"
            $Counter = 1

            # Output current activity
            Write-Host $Activity
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {
            if ($AccessToken) {

                # Build parameters
                $Parameters = @{
                    Method = $Method
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # If there are objects to update, foreach query with a query id
                if ($InputObject) {
                    
                    foreach ($Object in $InputObject) {
                        
                        # Update query ID, and if exists continue
                        $ObjectID = $Object.id
                        $ObjectDisplayName = $Object.displayName
                        if ($ObjectID) {

                            # Remove properties that are not valid for when updating objects
                            if ($CleanUpProperties) {
                                foreach ($Property in $CleanUpProperties) {
                                    $Object.PSObject.Properties.Remove("$Property")
                                }
                            }
                            
                            # Convert query object to JSON
                            $Object = $Object | ConvertTo-Json -Depth 10
                            
                            # Output progress
                            if ($InputObject.count -gt 1) {
                                Write-Host "Processing Query $Counter of $($InputObject.count) with ID: $ObjectID"

                                # Create progress bar
                                $PercentComplete = (($counter / $InputObject.count) * 100)
                                Write-Progress -Activity $Activity `
                                    -PercentComplete $PercentComplete `
                                    -CurrentOperation $ObjectDisplayName
                            }
                            else {
                                Write-Host "Processing Query with ID: $ObjectID"
                            }

                            # Increment counter
                            $counter++
                            
                            # Create query, with one second intervals to prevent throttling
                            Start-Sleep -Seconds 1
                            $AccessToken | Invoke-WTGraphQuery `
                                @Parameters `
                                -Uri $Uri/$ObjectID `
                                -Body $Object `
                            | Out-Null
                        }
                        else {
                            $ErrorMessage = "No IDs are specified, to update an object, an ID is required"
                            Write-Error $ErrorMessage
                        }
                    }
                }
                else {
                    $ErrorMessage = "There are no objects to be updated, to update an object, one must be supplied"
                    Write-Error $ErrorMessage
                    throw $ErrorMessage
                }
            }
            else {
                $ErrorMessage = "No access token specified, obtain an access token object from Get-WTGraphAccessToken"
                Write-Error $ErrorMessage
                throw $ErrorMessage
            }
        }
        catch {
            $ErrorMessage = "An exception has occurred, common reasons include patching properties that are not valid"
            Write-Error $ErrorMessage
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
