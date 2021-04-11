function Export-WTEMDevicePolicy {
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude the cleanup operations of the policies to be exported"
        )]
        [switch]$ExcludeExportCleanup,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude tag processing of policies"
        )]
        [switch]$ExcludeTagEvaluation,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The AzureAD policies to get, this must contain valid id(s), when not specified, all policies are returned"
        )]
        [Alias("Policy", "DevicePolicy")]
        [PSCustomObject]$DevicePolicies,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Endpoint Manager Device policies to get, this must contain valid id(s), when not specified, all device policies are returned"
        )]
        [Alias("id", "PolicyID", "PolicyIDs")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager Device policy type to get"
        )]
        [ValidateSet("Compliance", "Configuration")]
        [string]$PolicyType = "Compliance",
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
                "GraphAPI\Public\EndpointManager\DeviceManagement\Get-WTEMDevicePolicy.ps1",
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
                "lastModifiedDateTime",
                "SideIndicator",
                "version"
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

            # If policy object is provided, tag these
            if ($DevicePolicies) {

                # Evaluate the tags on the policies to be created, if not set to exclude
                if (!$ExcludeTagEvaluation) {
                    $DevicePolicies = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $DevicePolicies -PropertyToTag $PropertyToTag
                }
            }
            
            # If there are no policies to export, get policies based on specified parameters
            if (!$DevicePolicies) {
                
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
                        $Parameters.Add("PolicyIDs", $IDs)
                    }
                    if ($PolicyType) {
                        $Parameters.Add("PolicyType", $PolicyType)
                    }
                    
                    # Get all AzureAD policies
                    $DevicePolicies = Get-WTEMDevicePolicy @Parameters

                    if (!$DevicePolicies) {
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

            # If there are policies
            if ($DevicePolicies) {

                # Sort and filter (if devicelicable) policies
                $DevicePolicies = $DevicePolicies | Sort-Object displayName
                if (!$ExcludeExportCleanup) {
                    $DevicePolicies | Foreach-object {
                            
                        # Cleanup properties for export
                        foreach ($Property in $CleanUpProperties) {
                            $_.PSObject.Properties.Remove("$Property")
                        }
                    }
                }

                # Export to JSON
                Write-Host "Exporting Endpoint Manager Device Policies (Count: $($DevicePolicies.count))"

                # If a file path is specified, output all policies in one JSON formatted file
                if ($FilePath) {
                    $DevicePolicies | ConvertTo-Json -Depth 10 `
                    | Out-File -Force -FilePath $FilePath
                }
                else {
                    foreach ($Policy in $DevicePolicies) {

                        # Remove characters not supported in Windows file names
                        $PolicyDisplayName = $Policy.displayname -replace $UnsupportedCharactersRegEx, "_"
                        
                        # Concatenate directory, if not set to exclude, else, deviceend tag
                        if (!$ExcludeTagEvaluation) {
                            if ($Policy.$DirectoryTag) {
                                $Directory = "$DirectoryTag$Delimiter$($Policy.$DirectoryTag)"
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
                        Write-Host "Processing Policy $Counter with file name: $PolicyDisplayName.json"
                            
                        # Output individual Policy JSON file
                        $Policy | ConvertTo-Json -Depth 10 `
                        | Out-File -Force -FilePath "$Path\$Directory\$PolicyDisplayName.json"

                        # Increment counter
                        $Counter++
                    }
                }
            }
            else {
                $WarningMessage = "There are no Endpoint Manager Device $PolicyType policies to export"
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