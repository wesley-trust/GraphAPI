function Invoke-WTGraphPost {
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
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The objects to be created"
        )]
        [PSCustomObject]$InputObject,
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
            $Method = "Post"
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
                    Uri    = $Uri
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }

                # If there are policies to deploy, for each
                if ($InputObject) {
                    
                    foreach ($Object in $InputObject) {

                        # Remove properties that are not valid for when creating new objects
                        if ($CleanUpProperties) {
                            foreach ($Property in $CleanUpProperties) {
                                $Object.PSObject.Properties.Remove("$Property")
                            }
                        }
                        
                        # Update displayname variable prior to object conversion to JSON
                        $ObjectDisplayName = $Object.displayName

                        # Convert Query object to JSON
                        $Object = $Object | ConvertTo-Json -Depth 10

                        # Output progress
                        if ($InputObject.count -gt 1) {
                            if ($ObjectDisplayName) {
                                Write-Host "Processing Query $Counter of $($InputObject.count) with Display Name: $ObjectDisplayName"
                            }
                            else {
                                Write-Host "Processing Query $Counter of $($InputObject.count)"
                            }

                            # Create progress bar
                            $PercentComplete = (($counter / $InputObject.count) * 100)
                            Write-Progress -Activity $Activity `
                                -PercentComplete $PercentComplete `
                                -CurrentOperation $ObjectDisplayName
                        }
                        else {
                            if ($ObjectDisplayName) {
                                Write-Host "Processing Query with Display Name: $ObjectDisplayName"
                            }
                            else {
                                Write-Host "Processing Query"
                            }
                        }
                        
                        # Increment counter
                        $counter++

                        # Create record, with one second intervals to prevent throttling
                        Start-Sleep -Seconds 1
                        $AccessToken | Invoke-WTGraphQuery `
                            @Parameters `
                            -Body $Object
                    }
                }
                else {
                    $ErrorMessage = "There are no objects to be created, to create an object, one must be supplied"
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
            $ErrorMessage = "An exception has occurred, common reasons include posting properties that are not valid"
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
