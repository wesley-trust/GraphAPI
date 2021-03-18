function Invoke-WTGraphPatch {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Conditional Access Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Conditional Access Graph permissions"
        )]
        [string]$ClientSecret,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The initial domain (onmicrosoft.com) of the tenant"
        )]
        [string]$TenantDomain,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The access token, obtained from executing Get-WTGraphAccessToken"
        )]
        [string]$AccessToken,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
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
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
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

                # Change the API version if features in preview are to be excluded
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
                                Write-Host "Processing query $Counter of $($InputObject.count) with ID: $ObjectID"

                                # Create progress bar
                                $PercentComplete = (($counter / $InputObject.count) * 100)
                                Write-Progress -Activity $Activity `
                                    -PercentComplete $PercentComplete `
                                    -CurrentOperation $ObjectDisplayName
                            }
                            else {
                                Write-Host "Processing query $Counter with ID: $ObjectID"
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
                            $ErrorMessage = "The Conditional Access query does not contain an id, so cannot be updated"
                            Write-Error $ErrorMessage
                        }
                    }
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
