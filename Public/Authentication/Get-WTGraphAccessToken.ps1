function Get-WTGraphAccessToken {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client ID for the Azure AD service principal with Conditional Access Graph permissions"
        )]
        [string]$ClientID,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Client secret for the Azure AD service principal with Conditional Access Graph permissions"
        )]
        [string]$ClientSecret,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The initial domain (onmicrosoft.com) of the tenant"
        )]
        [string]$TenantDomain
    )
    Begin {
        try {

            # Variables
            $Method = "Post"
            $AuthenticationUrl = "https://login.microsoft.com"
            $ResourceUrl = "https://graph.microsoft.com"
            $GrantType = "client_credentials"
            $Uri = "oauth2/token?api-version=1.0"
            
            # Force TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {
            
            # Compose and invoke REST request
            $Body = @{
                grant_type    = $GrantType
                resource      = $ResourceUrl
                client_id     = $ClientID
                client_secret = $ClientSecret
            }
            
            $OAuth2 = Invoke-RestMethod `
                -Method $Method `
                -Uri $AuthenticationUrl/$TenantDomain/$Uri `
                -Body $Body

            # If an access token is returned, return this
            if ($OAuth2.access_token) {
                $OAuth2.access_token
            }
            else {
                $ErrorMessage = "Unable to obtain an access token for $TenantDomain but an exception has not occurred"
                Write-Error $ErrorMessage
            }
        }
        catch {
            $ErrorMessage = "Unable to obtain an access token for $TenantDomain, an exception has occurred which may have more information"
            Write-Error $ErrorMessage
            Write-Error -Message $_.Exception
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