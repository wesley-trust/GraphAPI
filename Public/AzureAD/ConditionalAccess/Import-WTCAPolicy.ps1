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

function Import-WTCAPolicy {
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
            HelpMessage = "The file path to the JSON file(s) that will be imported"
        )]
        [string[]]$FilePath,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The directory path(s) of which all JSON file(s) will be imported"
        )]
        [string]$Path,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Override the policy state when imported"
        )]
        [ValidateSet("enabled", "enabledForReportingButNotEnforced", "disabled", "")]
        [AllowNull()]
        [String]
        $PolicyState,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to update existing policies deployed in the tenant, where the IDs match"
        )]
        [switch]
        $UpdateExistingPolicies,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether existing policies deployed in the tenant will be removed, if not present in the import"
        )]
        [switch]
        $RemoveExistingPolicies,
        [Parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to the groups used for CA policies, should not be removed, if the policy is removed"
        )]
        [switch]
        $ExcludeGroupRemoval,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "If there are no policies to import, whether to forcibly remove any existing policies"
        )]
        [switch]$Force
    )
    Begin {
        try {
            # Function definitions
            $FunctionLocation = "$ENV:USERPROFILE\GitHub\Scripts\Functions"
            $Functions = @(
                "$FunctionLocation\GraphAPI\Get-WTGraphAccessToken.ps1",
                "$FunctionLocation\Toolkit\Invoke-WTPropertyTagging.ps1",
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\Remove-WTCAPolicy.ps1",
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\Get-WTCAPolicy.ps1",
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\New-WTCAPolicy.ps1"
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\New-WTCAGroup.ps1"
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\Edit-WTCAPolicy.ps1"
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\Export-WTCAPolicy.ps1"
                "$FunctionLocation\Azure\AzureAD\ConditionalAccess\Remove-WTCAGroup.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Tags = @("REF", "ENV")
            $PropertyToTag = "DisplayName"
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {
            
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
                    $Parameters += @{
                        ExcludePreviewFeatures = $true
                    }
                }

                # For each directory, get the file path of all JSON files within the directory
                if ($Path) {
                    $FilePath = foreach ($Directory in $Path) {
                        (Get-ChildItem -Path $Directory -Filter "*.json").FullName
                    }
                }

                # Import policies from JSON file
                $ConditionalAccessPolicies = foreach ($File in $FilePath) {
                    Get-Content -Raw -Path $File
                }

                # If a file has been imported, convert from JSON to an object for deployment
                if ($ConditionalAccessPolicies) {
                    $ConditionalAccessPolicies = $ConditionalAccessPolicies | ConvertFrom-Json
                    
                    # Output current action
                    Write-Host "Importing Conditional Access Policies (Count: $($ConditionalAccessPolicies.count))"
                }
                else {
                    $WarningMessage = "No Conditional Access policies to be imported"
                    Write-Warning $WarningMessage

                    # If there are no policies to import, but existing policies should be removed, for safety, "Force" is required
                    if ($RemoveExistingPolicies -and !$Force) {
                        $ErrorMessage = "To remove any existing policies use the switch -Force"
                        throw $ErrorMessage
                    }
                }
                
                # Evaluate policies if parameters exist
                if ($RemoveExistingPolicies -or $UpdateExistingPolicies) {

                    # Get existing policies for comparison
                    $ExistingPolicies = Get-WTCAPolicy @Parameters

                    if ($ExistingPolicies) {

                        if ($ConditionalAccessPolicies) {

                            # Compare object on id and pass thru all objects, including those that exist and are to be imported
                            $PolicyComparison = Compare-Object `
                                -ReferenceObject $ExistingPolicies `
                                -DifferenceObject $ConditionalAccessPolicies `
                                -Property id `
                                -PassThru
                                
                            # Filter for policies that should be removed, as they do not exist in the import
                            $RemovePolicies = $PolicyComparison | Where-Object { $_.sideindicator -eq "<=" }

                            # Filter for policies that did not contain an id, and so are policies that should be created
                            $CreatePolicies = $PolicyComparison | Where-Object { $_.sideindicator -eq "=>" }
                        }
                        else {

                            # If force is enabled, then if removal of policies is specified, all existing will be removed
                            if ($Force) {
                                $RemovePolicies = $ExistingPolicies
                            }
                        }

                        if ($RemoveExistingPolicies) {

                            # If policies require removing, pass the ids to the remove function
                            if ($RemovePolicies) {
                                $PolicyIDs = $RemovePolicies.id
                                Remove-WTCAPolicy @Parameters -PolicyIDs $PolicyIDs

                                # If the switch to not remove groups is not set, remove the groups for each Conditional Access policy also
                                if (!$ExcludeGroupRemoval) {
                                
                                    # Policy Include groups
                                    $PolicyIncludeGroupIDs = $RemovePolicies.conditions.users.includeGroups
                                
                                    # Policy Exclude groups
                                    $PolicyExcludeGroupIDs = $RemovePolicies.conditions.users.excludeGroups
                                
                                    # Combined unique list
                                    $PolicyGroupIDs = $PolicyIncludeGroupIDs + $PolicyExcludeGroupIDs | Sort-Object -Unique

                                    # Pass all groups, which will perform a check and remove only Conditional Access groups
                                    Remove-WTCAGroup @Parameters -IDs $PolicyGroupIDs
                                }
                            }
                            else {
                                $WarningMessage = "No policies will be removed, as none exist that are different to the import"
                                Write-Warning $WarningMessage
                            }

                        }
                        if ($UpdateExistingPolicies) {
                            if ($ConditionalAccessPolicies) {
                                
                                # Check whether the policies that could be updated have valid ids (so can be updated, ignore the rest)
                                $UpdatePolicies = foreach ($Policy in $ConditionalAccessPolicies) {
                                    if ($Policy.id -in $ExistingPolicies.id) {
                                        $Policy
                                    }
                                }

                                # If policies exist, with ids that matched the import
                                if ($UpdatePolicies) {
                            
                                    # Compare again, with all mandatory property elements for differences
                                    $PolicyPropertyComparison = Compare-Object `
                                        -ReferenceObject $ExistingPolicies `
                                        -DifferenceObject $UpdatePolicies `
                                        -Property id, displayName, state, sessionControls, conditions, grantControls

                                    $UpdatePolicies = $PolicyPropertyComparison | Where-Object { $_.sideindicator -eq "=>" }
                                }

                                # If policies require updating, pass the ids
                                if ($UpdatePolicies) {
                                    Edit-WTCAPolicy @Parameters -ConditionalAccessPolicies $UpdatePolicies -PolicyState $PolicyState
                                }
                                else {
                                    $WarningMessage = "No policies will be updated, as none exist that are different to the import"
                                    Write-Warning $WarningMessage
                                }
                            }
                        }
                    }
                    else {
                        # If no policies exist, any imported must be created
                        $CreatePolicies = $ConditionalAccessPolicies
                    }
                }
                else {
                    # If no policies are to be removed or updated, any imported must be created
                    $CreatePolicies = $ConditionalAccessPolicies
                }
                
                # If there are new policies to be created, create them, passing through the policy state
                if ($CreatePolicies) {
                        
                    # Remove existing tags, so these can be updated from the display name
                    foreach ($Tag in $Tags) {
                        $CreatePolicies | Foreach-Object {
                            $_.PSObject.Properties.Remove($Tag)
                        }
                    }
                        
                    # Evaluate the tags on the policies to be created
                    $TaggedPolicies = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $CreatePolicies -PropertyToTag $PropertyToTag

                    # Calculate the display names to be used for the CA groups
                    $CAGroupDisplayNames = foreach ($Policy in $TaggedPolicies) {
                        $DisplayName = $null
                        foreach ($Tag in $Tags) {
                            $DisplayName += $Tag + "-" + $Policy.$Tag + ";"
                        }
                        $DisplayName
                    }

                    # Create include and exclude groups
                    $ConditionalAccessIncludeGroups = New-WTCAGroup @Parameters -DisplayNames $CAGroupDisplayNames -GroupType Include
                    $ConditionalAccessExcludeGroups = New-WTCAGroup @Parameters -DisplayNames $CAGroupDisplayNames -GroupType Exclude
                        
                    # Tag groups
                    $TaggedCAIncludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $ConditionalAccessIncludeGroups -PropertyToTag $PropertyToTag
                    $TaggedCAExcludeGroups = Invoke-WTPropertyTagging -Tags $Tags -QueryResponse $ConditionalAccessExcludeGroups -PropertyToTag $PropertyToTag
                        
                    # For each policy, find the matching group
                    $CreatePolicies = foreach ($Policy in $TaggedPolicies) {
                            
                        # Find the matching include group
                        $CAIncludeGroup = $null
                        $CAIncludeGroup = $TaggedCAIncludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # Update the property with the group id, which must be in an array, and return the policy
                        $Policy.conditions.users.includeGroups = @($CAIncludeGroup.id)

                        # Find the matching exclude group
                        $CAExcludeGroup = $null
                        $CAExcludeGroup = $TaggedCAExcludeGroups | Where-Object {
                            $_.ref -eq $Policy.ref -and $_.env -eq $Policy.env
                        }

                        # Update the property with the group id, which must be in an array
                        $Policy.conditions.users.excludeGroups = @($CAExcludeGroup.id)
                            
                        # Return the policy
                        $Policy
                    }

                    # Create policies
                    $ConditionalAccessPolicies = New-WTCAPolicy @Parameters `
                        -ConditionalAccessPolicies $CreatePolicies `
                        -PolicyState $PolicyState
                        
                    # Update configuration files
                    Export-WTCAPolicy -ConditionalAccessPolicies $ConditionalAccessPolicies `
                        -Path $Path `
                        -ExcludeExportCleanup
                }
                else {
                    $WarningMessage = "No policies will be created, as none exist that are different to the import"
                    Write-Warning $WarningMessage
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
        
    }
}