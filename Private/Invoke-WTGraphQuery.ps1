<#
.Synopsis
    Execute a Microsoft Graph query
.Description
    This function will execute a query against Microsoft Graph and return the result
.PARAMETER Method
    The HTTP method for the Graph call (GET, POST, PUT, PATCH, DELETE).
.PARAMETER Uri
    The Uniform Resource Identifier for the Microsoft Graph API call, for example: "v1.0/users/"
.PARAMETER Body
    The request body of the Microsoft Graph API call. Used with methods such as POST, PUT and PATCH. Not required for GET.
.PARAMETER AccessToken
    The access token, obtained from executing Get-WTGraphAccessToken
.INPUTS
    None
.OUTPUTS
    None
.NOTES

.Example
    Invoke-WTGraphQuery -AccessToken $AccessToken -Method "GET" -Uri "v1.0/users/"
    $AccessToken | Invoke-WTGraphQuery -Method "GET" -Uri "v1.0/users/"
#>

function Invoke-WTGraphQuery {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The HTTP method for the Microsoft Graph call"
        )]
        [ValidateSet("Get", "Patch", "Post", "Delete", "Put")]
        [string]$Method,
        [parameter(
            Mandatory = $true,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The Uniform Resource Identifier for the Microsoft Graph API call"
        )]
        [string]$Uri,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The request body of the Microsoft Graph API call"
        )]
        [string]$Body,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            ValueFromPipeLine = $true,
            HelpMessage = "The access token, obtained from executing Get-WTGraphAccessToken"
        )]
        [string]$AccessToken,
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "Specify whether to exclude features in preview, a production API version will then be used instead"
        )]
        [switch]$ExcludePreviewFeatures
    )
    Begin {
        try {
            # Variables
            $ResourceUrl = "https://graph.microsoft.com"
            $ContentType = "application/json"
            $ApiVersion = "beta" # If preview features are in use, the "beta" API must be used

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

            if ($AccessToken) {

                # Change the API version if features in preview are to be excluded
                if ($ExcludePreviewFeatures) {
                    $ApiVersion = "v1.0"
                }

                $HeaderParameters = @{
                    "Content-Type"  = "application\json"
                    "Authorization" = "Bearer $AccessToken"
                }

                # Create an empty array to store the result
                $QueryRequest = @()
                $QueryResult = @()

                # If the request is to get data, invoke without a body, otherwise append body
                if ($Method -eq "GET") {
                    $QueryRequest = Invoke-RestMethod `
                        -Headers $HeaderParameters `
                        -Uri $ResourceUrl/$ApiVersion/$Uri `
                        -UseBasicParsing `
                        -Method $Method `
                        -ContentType $ContentType
                }
                else {
                    $QueryRequest = Invoke-RestMethod `
                        -Headers $HeaderParameters `
                        -Uri $ResourceUrl/$ApiVersion/$Uri `
                        -UseBasicParsing `
                        -Method $Method `
                        -ContentType $ContentType `
                        -Body $Body
                }
                
                # Check if a value is returned, and if not, whether an ID is, and add either to the query result, ignoring null objects returned
                if ($QueryRequest.value) {
                    $QueryResult += $QueryRequest.value
                }
                elseif ($QueryRequest.id) {
                    $QueryResult += $QueryRequest
                }

                # Invoke REST methods and fetch data until there are no pages left
                if ("$ResourceUrl/$Uri" -notlike "*`$top*") {
                    while ($QueryRequest."@odata.nextLink") {
                        $QueryRequest = Invoke-RestMethod `
                            -Headers $HeaderParameters `
                            -Uri $QueryRequest."@odata.nextLink" `
                            -UseBasicParsing `
                            -Method $Method `
                            -ContentType $ContentType

                        $QueryResult += $QueryRequest.value
                    }
                }
                
                # Return query result
                $QueryResult
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