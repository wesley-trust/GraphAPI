function Export-WTCAPolicy {
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
            HelpMessage = "The Conditional Access policies to get, this must contain valid id(s), when not specified, all policies are returned"
        )]
        [Alias("policy", "ConditionalAccessPolicy")]
        [pscustomobject]$ConditionalAccessPolicies,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Conditional Access policies to get, this must contain valid id(s), when not specified, all policies are returned"
        )]
        [Alias("id", "PolicyID")]
        [string[]]$PolicyIDs
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Policies\Get-WTCAPolicy.ps1",
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
            $Counter = 1
            $Tags = @("REF", "VER", "ENV")
            $PropertyToTag = "DisplayName"
            $DirectoryTag = "ENV"
            $Delimiter = "-"
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # If group object is provided, tag these
            if ($ConditionalAccessPolicies) {

                # Evaluate the tags on the policies to be created, if not set to exclude
                if (!$ExcludeTagEvaluation) {
                    $ConditionalAccessPolicies = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $ConditionalAccessPolicies -PropertyToTag $PropertyToTag
                }
            }
            
            # If there are no policies to export, get policies based on specified parameters
            if (!$ConditionalAccessPolicies) {
                
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
                    if ($PolicyIDs) {
                        $Parameters.Add("PolicyIDs", $IDs)
                    }

                    # Get all Conditional Access policies
                    $ConditionalAccessPolicies = Get-WTCAPolicy @Parameters

                    if (!$ConditionalAccessPolicies) {
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
            if ($ConditionalAccessPolicies) {
                    
                # Sort and filter (if applicable) policies
                $ConditionalAccessPolicies = $ConditionalAccessPolicies | Sort-Object displayName
                if (!$ExcludeExportCleanup) {
                    $ConditionalAccessPolicies | Foreach-object {
                            
                        # Cleanup properties for export
                        foreach ($Property in $CleanUpProperties) {
                            $_.PSObject.Properties.Remove("$Property")
                        }
                    }
                }

                # Export to JSON
                Write-Host "Exporting Conditional Access Policies (Count: $($ConditionalAccessPolicies.count))"
                    
                # If a file path is specified, output all policies in one JSON formatted file
                if ($FilePath) {
                    $ConditionalAccessPolicies | ConvertTo-Json -Depth 10 `
                    | Out-File -Force -FilePath $FilePath
                }
                else {
                    foreach ($Policy in $ConditionalAccessPolicies) {

                        # Remove characters not supported in Windows file names
                        $PolicyDisplayName = $Policy.displayname -replace $UnsupportedCharactersRegEx, "_"

                        # Concatenate directory, if not set to exclude, else, append tag
                        if (!$ExcludeTagEvaluation) {
                            $Directory = "$DirectoryTag$Delimiter$($Policy.$DirectoryTag)"
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
                        
                        # Output individual policy JSON file
                        $Policy | ConvertTo-Json -Depth 10 `
                        | Out-File -Force:$true -FilePath "$Path\$Directory\$PolicyDisplayName.json"

                        # Increment counter
                        $Counter++
                    }
                }
            }
            else {
                $WarningMessage = "There are no Conditional Access Policies to export"
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