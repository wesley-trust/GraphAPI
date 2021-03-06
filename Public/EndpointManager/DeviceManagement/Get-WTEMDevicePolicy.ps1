function Get-WTEMDevicePolicy {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Endpoint Manager policy Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Endpoint Manager policy Graph permissions"
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
            HelpMessage = "Specify whether to exclude features in preview, a production API version will be used instead"
        )]
        [switch]$ExcludePreviewFeatures,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude tag processing of policies"
        )]
        [switch]$ExcludeTagEvaluation,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The Endpoint Manager Device policies to get, this must contain valid id(s)"
        )]
        [Alias("id", "PolicyID", "PolicyIDs")]
        [string[]]$IDs,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify the Endpoint Manager Device policy type to get"
        )]
        [ValidateSet("Compliance", "Configuration")]
        [string]$PolicyType,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether scheduled actions for compliance policies are returned"
        )]
        [switch]$IncludeScheduledActions

    )
    Begin {
        try {
            # Function definitions
            $Functions = @(
                "GraphAPI\Public\Authentication\Get-WTGraphAccessToken.ps1",
                "GraphAPI\Private\Invoke-WTGraphGet.ps1"
            )

            # Function dot source
            foreach ($Function in $Functions) {
                . $Function
            }

            # Variables
            $Activity = "Getting Endpoint Manager Device $PolicyType policies"
            $Tags = @("SVC", "REF", "ENV")
            $Expand = "?`$expand=scheduledActionsForRule(`$expand=scheduledActionConfigurations)"

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
                
                # Variables based upon parameters
                if ($PolicyType -eq "Compliance") {
                    $Uri = "deviceManagement/deviceCompliancePolicies"
                }
                elseif ($PolicyType -eq "Configuration") {
                    $Uri = "deviceManagement/deviceConfigurations"
                }

                # Build Parameters
                $Parameters = @{
                    AccessToken = $AccessToken
                    Activity    = $Activity
                }
                if ($ExcludePreviewFeatures) {
                    $Parameters.Add("ExcludePreviewFeatures", $true)
                }
                if (!$ExcludeTagEvaluation) {
                    $Parameters.Add("Tags", $Tags)
                }

                # Get Endpoint Manager Device policies with scheduled actions
                if ($IncludeScheduledActions) {
                    if ($PolicyType -eq "Compliance") {
                        if (!$IDs) {
                            $Policies = Invoke-WTGraphGet @Parameters -Uri $Uri
                            $Ids = $Policies.id
                        }
                        if ($Ids) {
                            $QueryResponse = foreach ($Id in $IDs) {
                                Invoke-WTGraphGet @Parameters -Uri $Uri/$id/$Expand
                            }
                        }
                    }
                    else {
                        $ErrorMessage = "Only compliance policies can have scheduled actions, check if the parameters are correct"
                        throw $ErrorMessage
                    }
                }
                else {
                    if ($IDs) {
                        $Parameters.Add("IDs", $IDs)
                    }
                    
                    # Get Endpoint Manager Device policies
                    $QueryResponse = Invoke-WTGraphGet @Parameters -Uri $Uri
                }

                # Return response if one is returned
                if ($QueryResponse) {
                    $QueryResponse
                }
                else {
                    $WarningMessage = "No Device $PolicyType policies exist in Endpoint Manager, or with parameters specified"
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
        try {
            
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
}
