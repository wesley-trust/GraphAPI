<#
.Synopsis
    Export all Conditional Access groups to JSON
.Description
    This function exports the Conditional Access groups to JSON using the Microsoft Graph API.
    The following Microsoft Graph API permissions are required for the service principal used for authentication:
        Group.ReadWrite.ConditionalAccess
        Group.Read.All
        Directory.Read.All
        Agreement.Read.All
        Application.Read.All
.PARAMETER ClientID
    Client ID for the Azure AD service principal with Conditional Access Graph permissions
.PARAMETER ClientSecret
    Client secret for the Azure AD service principal with Conditional Access Graph permissions
.PARAMETER TenantName
    The initial domain (onmicrosoft.com) of the tenant
.PARAMETER AccessToken
    The access token, obtained from executing Get-WTGraphAccessToken
.PARAMETER FilePath
    The file path (including file name) of where the new JSON file will be created
.PARAMETER ExcludePreviewFeatures
    Specify whether to exclude features in preview, a production API version will then be used instead
.PARAMETER ExcludeExportCleanup
    Specify whether to exclude the cleanup operations of the groups to be exported
.INPUTS
    None
.OUTPUTS
    JSON file with all Conditional Access groups
.NOTES

.Example
    $Parameters = @{
                ClientID = ""
                ClientSecret = ""
                TenantDomain = ""
                FilePath = ""
    }
    Export-WTCAGroup @Parameters
    $AccessToken | Export-WTCAGroup
#>

function Export-WTCAGroups {
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
            HelpMessage = "The Conditional Access groups to get, this must contain valid id(s), when not specified, all groups are returned"
        )]
        [Alias("Group", "ConditionalAccessGroup")]
        [pscustomobject]$ConditionalAccessGroups,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Conditional Access groups to get, this must contain valid id(s), when not specified, all groups are returned"
        )]
        [Alias("id", "GroupID")]
        [string[]]$GroupIDs
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Groups\Get-WTCAGroup.ps1"
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
            $DirectoryTag = "SVC"
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
            
            # If there are no groups to export, get groups based on specified parameters
            if (!$ConditionalAccessGroups) {
                
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
                        $Parameters += @{
                            ExcludeTagEvaluation = $true
                        }
                    }
                    if ($ExcludePreviewFeatures) {
                        $Parameters += @{
                            ExcludePreviewFeatures = $true
                        }
                    }
                    if ($GroupIDs) {
                        $Parameters += @{
                            GroupIDs = $GroupIDs
                        }
                    }
                    
                    # Get all Conditional Access groups
                    $ConditionalAccessGroups = Get-WTCAGroup @Parameters

                    if (!$ConditionalAccessGroups) {
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
            if ($ConditionalAccessGroups) {
                    
                # Sort and filter (if applicable) groups
                $ConditionalAccessGroups = $ConditionalAccessGroups | Sort-Object displayName
                if (!$ExcludeExportCleanup) {
                    $ConditionalAccessGroups | Foreach-object {
                            
                        # Cleanup properties for export
                        foreach ($Property in $CleanUpProperties) {
                            $_.PSObject.Properties.Remove("$Property")
                        }
                    }
                }

                # Evaluate the tags on the policies to be created, if not set to exclude
                if (!$ExcludeTagEvaluation) {
                    $ConditionalAccessGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $ConditionalAccessGroups -PropertyToTag $PropertyToTag
                }

                # Export to JSON
                Write-Host "Exporting Conditional Access groups (Count: $($ConditionalAccessGroups.count))"

                # If a file path is specified, output all groups in one JSON formatted file
                if ($FilePath) {
                    $ConditionalAccessGroups | ConvertTo-Json -Depth 10 `
                    | Out-File -Force:$true -FilePath $FilePath
                }
                else {
                    foreach ($Group in $ConditionalAccessGroups) {

                        # Remove characters not supported in Windows file names
                        $GroupDisplayName = $Group.displayname -replace $UnsupportedCharactersRegEx, "_"
                        
                        # Concatenate directory, if not set to exclude, else, append tag
                        if (!$ExcludeTagEvaluation) {
                            $Directory = "$DirectoryTag$Delimiter$($Group.$DirectoryTag)"
                        }
                        else {
                            $Directory = ".."
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
                        | Out-File -Force:$true -FilePath "$Path\$Directory\$GroupDisplayName.json"

                        # Increment counter
                        $Counter++
                    }
                }
            }
            else {
                $WarningMessage = "There are no Conditional Access groups to export"
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