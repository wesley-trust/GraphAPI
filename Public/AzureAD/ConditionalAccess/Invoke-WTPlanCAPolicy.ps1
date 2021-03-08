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

function Invoke-WTPlanCAPolicy {
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
            HelpMessage = "The Conditional Access policy object"
        )]
        [pscustomobject]$ConditionalAccessPolicies,
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
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "Toolkit\Public\Invoke-WTPropertyTagging.ps1",
                "GraphAPI\Public\AzureAD\ConditionalAccess\Get-WTCAPolicy.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

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

                # Output current action
                Write-Host "Evaluating Conditional Access Policies"
                
                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters += @{
                        ExcludePreviewFeatures = $true
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

                        if (!$RemoveExistingPolicies) {

                            # If policies are not to be removed, disregard any policies for removal
                            $RemovePolicies = $null
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
                
                # Build object to return
                $PlanCAPolicies = [ordered]@{}

                if ($RemovePolicies) {
                    $PlanCAPolicies.Add("RemovePolicies", $RemovePolicies)
                    
                    # Output current action
                    Write-Host "Policies to remove: $($RemovePolicies.count)"

                    foreach ($Policy in $RemovePolicies) {
                        Write-Host "Remove: Policy ID: $($Policy.id)" -ForegroundColor DarkRed
                    }
                }
                if ($UpdatePolicies) {
                    $PlanCAPolicies.Add("UpdatePolicies", $UpdatePolicies)
                                        
                    # Output current action
                    Write-Host "Policies to update: $($UpdatePolicies.count)"
                    
                    foreach ($Policy in $UpdatePolicies) {
                        Write-Host "Update: Policy ID: $($Policy.id)" -ForegroundColor DarkYellow
                    }
                }
                if ($CreatePolicies) {
                    $PlanCAPolicies.Add("CreatePolicies", $CreatePolicies)
                                        
                    # Output current action
                    Write-Host "Policies to create: $($CreatePolicies.count)"

                    foreach ($Policy in $CreatePolicies) {
                        Write-Host "Create: Policy Name: $($Policy.displayName)" -ForegroundColor DarkGreen
                    }
                }

                # If there are policies, return PS object
                if ($PlanCAPolicies) {
                    $PlanCAPolicies = [pscustomobject]$PlanCAPolicies
                    $PlanCAPolicies
                }
                else {
                    Write-Host = "No policies will be created, updated or removed, as none exist that are different to the import"
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