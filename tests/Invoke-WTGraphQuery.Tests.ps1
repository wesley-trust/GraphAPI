BeforeAll {
    . "$PSScriptRoot/../Private/Invoke-WTGraphQuery.ps1"
}

Describe 'Invoke-WTGraphQuery' {
    It 'Throws an error when AccessToken is missing' {
        { Invoke-WTGraphQuery -Method Get -Uri 'me' } | Should -Throw
    }

    It 'Sets the Content-Type header to application/json' {
        $script:HeaderValue = $null
        # Mock Invoke-RestMethod to capture headers
        Mock -CommandName Invoke-RestMethod -MockWith {
            param($Headers)
            $script:HeaderValue = $Headers['Content-Type']
        }
        Invoke-WTGraphQuery -Method Get -Uri 'me' -AccessToken 'token'
        $script:HeaderValue | Should -Be 'application/json'
    }
}
