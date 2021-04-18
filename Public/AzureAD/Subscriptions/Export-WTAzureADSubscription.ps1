function Export-WTAzureADSubscription {
    [CmdletBinding()]
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
            HelpMessage = "The Subscriptions to get, this must contain valid id(s), when not specified, all policies are returned"
        )]
        [Alias("DefinedSubscription","Subscription","Subscriptions")]
        [PSCustomObject]$DefinedSubscriptions,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Subscriptions to get, this must contain valid id(s), when not specified, all policies are returned"
        )]
        [Alias("id", "SubscriptionID")]
        [string[]]$SubscriptionIDs
    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Public\AzureAD\Subscriptions\Get-WTAzureADSubscription.ps1"
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
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {
            
            # If there are no policies to export, get policies based on specified parameters
            if (!$DefinedSubscriptions) {
                
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
                    if ($ExcludePreviewFeatures) {
                        $Parameters.Add("ExcludePreviewFeatures", $true)
                    }
                    if ($SubscriptionIDs) {
                        $Parameters.Add("SubscriptionIDs", $IDs)
                    }

                    # Get all Subscriptions
                    $DefinedSubscriptions = Get-Get-WTAzureADSubscription @Parameters

                    if (!$DefinedSubscriptions) {
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
            if ($DefinedSubscriptions) {
                    
                # Sort and filter (if applicable) policies
                $DefinedSubscriptions = $DefinedSubscriptions | Sort-Object skuPartNumber
                if (!$ExcludeExportCleanup) {
                    $DefinedSubscriptions | Foreach-object {
                            
                        # Cleanup properties for export
                        foreach ($Property in $CleanUpProperties) {
                            $_.PSObject.Properties.Remove("$Property")
                        }
                    }
                }

                # Export to JSON
                Write-Host "Exporting Subscriptions (Count: $($DefinedSubscriptions.count))"
                    
                # If a file path is specified, output all policies in one JSON formatted file
                if ($FilePath) {
                    $DefinedSubscriptions | ConvertTo-Json -Depth 10 `
                    | Out-File -Force -FilePath $FilePath
                }
                else {
                    foreach ($Subscription in $DefinedSubscriptions) {

                        # Remove characters not supported in Windows file names
                        $SubscriptionDisplayName = $Subscription.skuPartNumber -replace $UnsupportedCharactersRegEx, "_"

                        # If directory path does not exist for export, create it
                        $TestPath = Test-Path $Path -PathType Container
                        if (!$TestPath) {
                            New-Item -Path $Path -ItemType Directory | Out-Null
                        }

                        # Output current status
                        Write-Host "Processing Subscription $Counter with file name: $SubscriptionDisplayName.json"
                        
                        # Output individual policy JSON file
                        $Subscription | ConvertTo-Json -Depth 10 `
                        | Out-File -Force:$true -FilePath "$Path\$SubscriptionDisplayName.json"

                        # Increment counter
                        $Counter++
                    }
                }
            }
            else {
                $WarningMessage = "There are no Subscriptions to export"
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