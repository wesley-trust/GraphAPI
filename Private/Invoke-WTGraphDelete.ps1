function Invoke-WTGraphDelete {
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
            HelpMessage = "The specific record ids to be returned"
        )]
        [Alias("id")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The uniform resource indicator"
        )]
        [string]$Uri,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The activity being performed"
        )]
        [string]$Activity
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
            $Method = "Delete"
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

                # If there are objects to be removed, 
                if ($IDs) {
                    foreach ($ID in $IDs) {

                        # Output progress
                        if ($IDs.count -gt 1) {
                            Write-Host "Processing Query $Counter of $($IDs.count) with ID: $ID"

                            # Create progress bar
                            $PercentComplete = (($counter / $IDs.count) * 100)
                            Write-Progress -Activity $Activity `
                                -PercentComplete $PercentComplete `
                                -CurrentOperation $ID
                        }
                        else {
                            Write-Host "Processing Query with ID: $ID"
                        }
                        
                        # Increment counter
                        $counter++

                        # Remove record, one second apart to prevent throttling
                        Start-Sleep -Seconds 1
                        $AccessToken | Invoke-WTGraphQuery `
                            @Parameters `
                            -Uri $Uri/$ID `
                        | Out-Null
                    }
                }
                else {
                    $ErrorMessage = "No IDs are specified, to remove an object, an ID is required"
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
