function Export-WTGroupTemplate {
    [cmdletbinding()]
    param (
        [parameter(
            Mandatory = $false,
            ValueFromPipeLineByPropertyName = $true,
            HelpMessage = "The path where the JSON file will be created"
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
            HelpMessage = "Specify whether to include optional properties"
        )]
        [switch]$IncludeOptionalProperties
    )
    Begin {
        try {
            
            # Variables
            $TemplateProperties = [ordered]@{
                displayName     = $null
                mailEnabled     = $null
                mailNickname    = $null
                securityEnabled = $null
            }
        }
        catch {
            Write-Error -Message $_.Exception
            throw $_.exception
        }
    }
    Process {
        try {

            # If, in addition to required properties, optional properties should be included
            if ($IncludeOptionalProperties) {
                $TemplateProperties.Add("description", $null)
                $TemplateProperties.Add("owners", $null)
                $TemplateProperties.Add("members", $null)
                $TemplateProperties.Add("visibility", $null)
            }

            # Export to JSON
            if ($FilePath) {
                $TemplateProperties | ConvertTo-Json -Depth 10 `
                | Out-File -Force -FilePath $FilePath
            }
            else {
                $TemplateProperties | ConvertTo-Json -Depth 10 `
                | Out-File -Force -FilePath "$Path\GroupTemplate.json"
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