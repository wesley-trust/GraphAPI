function Export-WTAzureADGroup {
    [cmdletbinding()]
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude the cleanup operations of the groups to be exported"
        )]
        [switch]$ExcludeExportCleanup,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude tag processing of groups"
        )]
        [switch]$ExcludeTagEvaluation,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The AzureAD groups to get, this must contain valid id(s), when not specified, all groups are returned"
        )]
        [Alias("Group", "AzureADGroup")]
        [pscustomobject]$AzureADGroups,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The AzureAD groups to get, this must contain valid id(s), when not specified, all groups are returned"
        )]
        [Alias("id", "GroupID", "GroupIDs")]
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
                "GraphAPI\Public\AzureAD\Groups\Get-WTAzureADGroup.ps1",
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

            # If group object is provided, tag these
            if ($AzureADGroups) {

                # Evaluate the tags on the policies to be created, if not set to exclude
                if (!$ExcludeTagEvaluation) {
                    $AzureADGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $AzureADGroups -PropertyToTag $PropertyToTag
                }
            }
            
            # If there are no groups to export, get groups based on specified parameters
            if (!$AzureADGroups) {
                
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
                        $Parameters.Add("GroupIDs", $IDs)
                    }
                    
                    # Get all AzureAD groups
                    $AzureADGroups = Get-WTAzureADGroup @Parameters

                    if (!$AzureADGroups) {
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

            # If there are groups
            if ($AzureADGroups) {

                # Sort and filter (if applicable) groups
                $AzureADGroups = $AzureADGroups | Sort-Object displayName
                if (!$ExcludeExportCleanup) {
                    $AzureADGroups | Foreach-object {
                            
                        # Cleanup properties for export
                        foreach ($Property in $CleanUpProperties) {
                            $_.PSObject.Properties.Remove("$Property")
                        }
                    }
                }

                # Export to JSON
                Write-Host "Exporting AzureAD Groups (Count: $($AzureADGroups.count))"

                # If a file path is specified, output all groups in one JSON formatted file
                if ($FilePath) {
                    $AzureADGroups | ConvertTo-Json -Depth 10 `
                    | Out-File -Force -FilePath $FilePath
                }
                else {
                    foreach ($Group in $AzureADGroups) {

                        # Remove characters not supported in Windows file names
                        $GroupDisplayName = $Group.displayname -replace $UnsupportedCharactersRegEx, "_"
                        
                        # Concatenate directory, if not set to exclude, else, append tag
                        if (!$ExcludeTagEvaluation) {
                            $Directory = "$DirectoryTag$Delimiter$($Group.$DirectoryTag)"
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
                        Write-Host "Processing Group $Counter with file name: $GroupDisplayName.json"
                            
                        # Output individual Group JSON file
                        $Group | ConvertTo-Json -Depth 10 `
                        | Out-File -Force -FilePath "$Path\$Directory\$GroupDisplayName.json"

                        # Increment counter
                        $Counter++
                    }
                }
            }
            else {
                $WarningMessage = "There are no AzureAD groups to export"
                Write-Warning $WarningMessage
            }
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    End {

    }
}