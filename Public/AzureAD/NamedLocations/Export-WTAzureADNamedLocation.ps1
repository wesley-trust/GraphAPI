function Export-WTAzureADNamedLocation {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with AzureAD Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with AzureAD Graph permissions"
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
            HelpMessage = "The path where the JSON file(s) will be created"
        )]
        [string]$Path,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The file path where the JSON file will be created"
        )]
        [string]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude the cleanup operations of the named locations to be exported"
        )]
        [switch]$ExcludeExportCleanup,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude tag processing of named locations"
        )]
        [switch]$ExcludeTagEvaluation,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The AzureAD named locations to get, this must contain valid id(s), when not specified, all named locations are returned"
        )]
        [Alias("NamedLocation", "NamedLocations", "AzureADNamedLocation")]
        [PSCustomObject]$AzureADNamedLocations,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The AzureAD named locations to get, this must contain valid id(s), when not specified, all named locations are returned"
        )]
        [Alias("id", "NamedLocationID", "NamedLocationIDs")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The tag to use as the subdirectory to organise the export, default is 'SVC'"
        )]
        [Alias("Tag")]
        [string]$DirectoryTag = "SVC"
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\NamedLocations\Get-WTAzureADNamedLocation.ps1",
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }
            
            # Variables
            $CleanUpProperties = (
                "id",
                "createdDateTime",
                "modifiedDateTime"
            )
            $UnsupportedCharactersRegEx = '[\\\/:*?"<>|]'
            $Tags = @("SVC", "REF", "ENV")
            $PropertyToTag = "DisplayName"
            $Delimiter = "-"
            $Counter = 1
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # If named location object is provided, tag these
            if ($AzureADNamedLocations) {

                # Evaluate the tags on the named locations to be created, if not set to exclude
                if (!$ExcludeTagEvaluation) {
                    $AzureADNamedLocations = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $AzureADNamedLocations -PropertyToTag $PropertyToTag
                }
            }
            
            # If there are no named locations to export, get named locations based on specified parameters
            if (!$AzureADNamedLocations) {
                
                # If there is no access token, obtain one
                if (!$AccessToken) {
                    $AccessToken = Get-WTGraphAccessToken `
                        -ClientID $ClientID `
                        -ClientSecret $ClientSecret `
                        -TenantDomain $TenantDomain
                }

                if ($AccessToken) {

                    # Build Parameters
                    $Parameters = @{
                        AccessToken = $AccessToken
                    }
                    if ($ExcludeTagEvaluation) {
                        $Parameters.Add("ExcludeTagEvaluation", $true)
                    }
                    if ($ExcludePreviewFeatures) {
                        $Parameters.Add("ExcludePreviewFeatures", $true)
                    }
                    if ($IDs) {
                        $Parameters.Add("NamedLocationIDs", $IDs)
                    }
                    
                    # Get all AzureAD named locations
                    $AzureADNamedLocations = Get-WTAzureADNamedLocation @Parameters

                    if (!$AzureADNamedLocations) {
                        $ErrorMessage = "Microsoft Graph did not return a valid response"
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

            # If there are named locations
            if ($AzureADNamedLocations) {

                # Sort and filter (if applicable) named locations
                $AzureADNamedLocations = $AzureADNamedLocations | Sort-Object displayName
                if (!$ExcludeExportCleanup) {
                    $AzureADNamedLocations | Foreach-object {
                            
                        # Cleanup properties for export
                        foreach ($Property in $CleanUpProperties) {
                            $_.PSObject.Properties.Remove("$Property")
                        }
                    }
                }

                # Export to JSON
                Write-Host "Exporting AzureAD Named Locations (Count: $($AzureADNamedLocations.count))"

                # If a file path is specified, output all named locations in one JSON formatted file
                if ($FilePath) {
                    $AzureADNamedLocations | ConvertTo-Json -Depth 10 `
                    | Out-File -Force -FilePath $FilePath
                }
                else {
                    foreach ($Location in $AzureADNamedLocations) {

                        # Remove characters not supported in Windows file names
                        $LocationDisplayName = $Location.displayname -replace $UnsupportedCharactersRegEx, "_"
                        
                        # Concatenate directory, if not set to exclude, else, append tag
                        if (!$ExcludeTagEvaluation) {
                            if ($Location.$DirectoryTag) {
                                $Directory = "$DirectoryTag$Delimiter$($Location.$DirectoryTag)"
                            }
                            else {
                                $Directory = "\"
                            }
                        }
                        else {
                            $Directory = "\"
                        }
                            
                        # If directory path does not exist for export, create it
                        $TestPath = Test-Path $Path\$Directory -PathType Container
                        if (!$TestPath) {
                            New-Item -Path $Path\$Directory -ItemType Directory | Out-Null
                        }

                        # Output current status
                        Write-Host "Processing Named Location $Counter with file name: $LocationDisplayName.json"
                            
                        # Output individual Named Location JSON file
                        $Location | ConvertTo-Json -Depth 10 `
                        | Out-File -Force -FilePath "$Path\$Directory\$LocationDisplayName.json"

                        # Increment counter
                        $Counter++
                    }
                }
            }
            else {
                $WarningMessage = "There are no AzureAD named locations to export"
                Write-Warning $WarningMessage
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