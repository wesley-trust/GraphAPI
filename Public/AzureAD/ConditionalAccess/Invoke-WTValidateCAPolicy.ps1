<#
.Synopsis
    Import all Conditional Access policies from JSON definition
.Description
    This function imports the Conditional Access policies from JSON using the Microsoft Graph API.
    The following Microsoft Graph API permissions are required for the service principal used for authentication:
        Policy.ReadWrite.ConditionalAccess
        Policy.Read.All
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
    The file path to the JSON file that will be imported
.PARAMETER PolicyState
    Modify the policy state when imported, when not specified the policy will maintain state
.PARAMETER RemoveAllExistingPolicies
    Specify whether all existing policies deployed in the tenant will be removed
.PARAMETER ExcludePreviewFeatures
    Specify whether to exclude features in preview, a production API version will then be used instead
.INPUTS
    JSON file with all Conditional Access policies
.OUTPUTS
    None
.NOTES

.Example
    $Parameters = @{
                ClientID = ""
                ClientSecret = ""
                TenantDomain = ""
                FilePath = ""
    }
    Import-WTCAPolicy.ps1 @Parameters
    Import-WTCAPolicy.ps1 -AccessToken $AccessToken -FilePath ""
#>

function Invoke-WTValidateCAPolicy {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The file path to the JSON file(s) that will be imported"
        )]
        [string[]]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory path(s) of which all JSON file(s) will be imported"
        )]
        [string]$Path
    )
    Begin {
        try {

        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # For each directory, get the file path of all JSON files within the directory, if the directory exists
            if ($Path) {
                $PathExists = Test-Path -Path $Path
                if ($PathExists) {
                    $FilePath = foreach ($Directory in $Path) {
                        (Get-ChildItem -Path $Directory -Filter "*.json").FullName
                    }
                }
            }

            # Import policies from JSON file
            if ($FilePath) {
                $ConditionalAccessPolicies = foreach ($File in $FilePath) {
                    Get-Content -Raw -Path $File
                }
            }

            # If a file has been imported, convert from JSON to an object for deployment
            if ($ConditionalAccessPolicies) {
                $ConditionalAccessPolicies = $ConditionalAccessPolicies | ConvertFrom-Json
                
                # Output current action
                Write-Host "Importing Conditional Access Policies"
                Write-Host "Policies: $($ConditionalAccessPolicies.count)"
                
                foreach ($Policy in $ConditionalAccessPolicies){
                    Write-Host "Import: Policy Name: $($Policy.displayName)"
                }
                
                # TODO: Validate import contains mandatory fields
                if ($ConditionalAccessPolicies) {

                    $ValidateCAPolicies = $ConditionalAccessPolicies
                    
                    # Return policies
                    $ValidateCAPolicies
                }
                else {
                    $WarningMessage = "No Conditional Access policies to be imported, import may have failed or none may exist"
                    Write-Warning $WarningMessage
                }
            }
            else {
                $WarningMessage = "No Conditional Access policies to be imported, import may have failed or none may exist"
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