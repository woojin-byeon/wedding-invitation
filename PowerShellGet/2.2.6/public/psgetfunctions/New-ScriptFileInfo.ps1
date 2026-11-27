function New-ScriptFileInfo
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding=$false,
                   SupportsShouldProcess=$true,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkId=619792')]
    Param
    (
        [Parameter(Mandatory=$false,
                   Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $CompanyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Copyright,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Object[]]
        $RequiredModules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalModuleDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequiredScripts,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalScriptDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
        [string]
        $PrivateData,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $Force
    )

    Process
    {
        if($Path)
        {
            if(-not $Path.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase))
            {
                $errorMessage = ($LocalizedData.InvalidScriptFilePath -f $Path)
                ThrowError  -ExceptionName 'System.ArgumentException' `
                            -ExceptionMessage $errorMessage `
                            -ErrorId 'InvalidScriptFilePath' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ExceptionObject $Path `
                            -ErrorCategory InvalidArgument
                return
            }

            if(-not $Force -and (Microsoft.PowerShell.Management\Test-Path -Path $Path))
            {
                $errorMessage = ($LocalizedData.ScriptFileExist -f $Path)
                ThrowError  -ExceptionName 'System.ArgumentException' `
                            -ExceptionMessage $errorMessage `
                            -ErrorId 'ScriptFileExist' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ExceptionObject $Path `
                            -ErrorCategory InvalidArgument
                return
            }
        }
        elseif(-not $PassThru)
        {
            ThrowError  -ExceptionName 'System.ArgumentException' `
                        -ExceptionMessage $LocalizedData.MissingTheRequiredPathOrPassThruParameter `
                        -ErrorId 'MissingTheRequiredPathOrPassThruParameter' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument
            return
        }

        if(-not $Version)
        {
            $Version = '1.0'
        }
        else
        {
            $result = ValidateAndGet-VersionPrereleaseStrings -Version $Version -CallerPSCmdlet $PSCmdlet
            if (-not $result)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
        }

        if(-not $Author)
        {
            if($script:IsWindows)
            {
                $Author = (Get-EnvironmentVariable -Name 'USERNAME' -Target $script:EnvironmentVariableTarget.Process -ErrorAction SilentlyContinue)
            }
            else
            {
                $Author = $env:USER
            }
        }

        if(-not $Guid)
        {
            $Guid = [System.Guid]::NewGuid()
        }

        $params = @{
            Version = $Version
            Author = $Author
            Guid = $Guid
            CompanyName = $CompanyName
            Copyright = $Copyright
            ExternalModuleDependencies = $ExternalModuleDependencies
            RequiredScripts = $RequiredScripts
            ExternalScriptDependencies = $ExternalScriptDependencies
            Tags = $Tags
            ProjectUri = $ProjectUri
            LicenseUri = $LicenseUri
            IconUri = $IconUri
            ReleaseNotes = $ReleaseNotes
			PrivateData = $PrivateData
        }

        if(-not (Validate-ScriptFileInfoParameters -parameters $params))
        {
            return
        }

        if("$Description" -match '<#' -or "$Description" -match '#>')
        {
            $message = $LocalizedData.InvalidParameterValue -f ($Description, 'Description')
            Write-Error -Message $message -ErrorId 'InvalidParameterValue' -Category InvalidArgument

            return
        }

        $PSScriptInfoString = Get-PSScriptInfoString @params

        $requiresStrings = Get-RequiresString -RequiredModules $RequiredModules

        $ScriptCommentHelpInfoString = Get-ScriptCommentHelpInfoString -Description $Description

        $ScriptMetadataString = $PSScriptInfoString
        $ScriptMetadataString += "`r`n"

        if("$requiresStrings".Trim())
        {
            $ScriptMetadataString += "`r`n"
            $ScriptMetadataString += $requiresStrings -join "`r`n"
            $ScriptMetadataString += "`r`n"
        }

        $ScriptMetadataString += "`r`n"
        $ScriptMetadataString += $ScriptCommentHelpInfoString
        $ScriptMetadataString += "Param()`r`n`r`n"

        $tempScriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Get-Random).ps1"

        try
        {
            Microsoft.PowerShell.Management\Set-Content -Value $ScriptMetadataString -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

            $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

            if(-not $scriptInfo)
            {
                # Above Test-ScriptFileInfo cmdlet writes the errors
                return
            }

    	    if($Path -and ($Force -or $PSCmdlet.ShouldProcess($Path, ($LocalizedData.NewScriptFileInfowhatIfMessage -f $Path) )))
    	    {
                Microsoft.PowerShell.Management\Copy-Item -Path $tempScriptFilePath -Destination $Path -Force -WhatIf:$false -Confirm:$false
            }

            if($PassThru)
            {
                Write-Output -InputObject $ScriptMetadataString
            }
        }
        finally
        {
            Microsoft.PowerShell.Management\Remove-Item -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
}
# SIG # Begin signature block
# MIInJwYJKoZIhvcNAQcCoIInGDCCJxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDB+nlyZpNmrVvk
# shyKvQyz8FhtdlI68R5SwPUPiAnKeKCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
# yE7XD1dIAAAAAAIdMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjQwHhcNMjYwNDE2MTg1OTQzWhcNMjcwNDE1MTg1
# OTQzWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYD
# VQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDQvewXxx9gZZFC6Ys1WBay8BJ8kGA4JQnH5CMafqOASlTpK9H8
# o5ZXTXt0caVQTNMUPt445wXYD+dFtaKWTwDn1I52oUSrC9vJin1Gsqt+zyKJL5Dg
# 3eQXbQNR61DmMy20GLTIO3SFed9Rfi/ophgCLGFLDR3r0KvHjwMb/jYWS0celV/4
# Lz27LfAekm8v9E5IXaeiXbAUYZKK090n4CVl3JBtbN+9DtI9SNu/yjvozW52/u7R
# X/Ttpa/KDlpuokZ+Zcbvmtd9ur9gFLvZzh41o9MsE/clQtdaFWGvuo6Jua/ntpgk
# ey3E5/vBFe+MJPG6phdnuo6r57ZudCudiI1bAgMBAAGjggGbMIIBlzAOBgNVHQ8B
# Af8EBAMCB4AwHwYDVR0lBBgwFgYKKwYBBAGCN0wIAQYIKwYBBQUHAwMwHQYDVR0O
# BBYEFH6QuMwqcPG0hQlQ6c5jCtTTLrVeMEUGA1UdEQQ+MDykOjA4MR4wHAYDVQQL
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xFjAUBgNVBAUTDTIzMDAxMis1MDc1NTkw
# HwYDVR0jBBgwFoAUf1k/VCHarU/vBeXmo9ctBpQSCDEwYAYDVR0fBFkwVzBVoFOg
# UYZPaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0
# JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNybDBtBggrBgEFBQcBAQRh
# MF8wXQYIKwYBBQUHMAKGUWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNy
# dDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBKTbYOjzwTG/DXGaz9
# s6+fQeaTtDcFmMY+5UyVFCyj7Pv+5i37qfX8lSL/tBIfYQfWsMuBQlfZurJD6r4H
# VJ2CeH+1fgiq8dcHdVKoZ3Sa2qXoX3cq9iS8cVb06B7+5/XJ7I0OxHH9fDsvJ3T3
# w5V/ZtAIFmLrl+P0CtG+92uzRsn0nTbdFjOkLMLWPLAU3THohKRlSEMgFJpPkm5n
# 5UAZ35xX6FWCrDLsSKb555bTifwa8mJBwdlof0bmfYidH+dxZ1FdDxvLnNl9zeKs
# A4kejaaIqqIPguhwAti5Ql7BlTNoJNwxCvBmqW2MQLnCkYN/VVUsR3V2x/rcTNzo
# Bf/Z/SpROvdaA2ZOOd1uioXJt3tdLQ7vHpqpib0KfWr/FWXW10q38VxfCnRQBqzb
# SuztR7nEMuzX7Ck+B/XaPDXd1qh72+QYyB0Z2VzWmO9zsnb9Uq/dwu8LGeQqnyu6
# 7SDGACvnXii2fb9+US492VTnXSnFKyqwgzUyFMtZK1/sHYTv6bG4TtQUygQxTN+Z
# V+aJIlKO2MqZ7bKrAnOzS9m6NgoTdWOq11bTOZwKlIEV/EhV9SWkDmdpR/hPPT2v
# 6TEj4F8PT/zHjRezIU5c/DGlt/VhY/pK0XkJtEyMmmS1BMtjU/rqBZVMIm3dnxQs
# /TBByr+Cf8Z1r7aifQVQ+WSqzjCCBr0wggSloAMCAQICEzMAAAA5O7Y3Gb8GHWcA
# AAAAADkwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDExMB4XDTI0MDgwODIwNTQxOFoXDTM2MDMyMjIyMTMwNFow
# VzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEo
# MCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAyNDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBANgBnB7jOMeqlRYHNa265v4IY9fH8TKh
# emHfPINe1gpLaV3dhg324WwH06LcHbpnsBukCDNitryo0dtS/EW6I/yEL/bLSY8h
# KpbfQuWusBPr9qazYcDxCW/qnjb5JsI1s8bNOg3bVATvQVL4tcf03aTycsz8QeCd
# M0l/yHRObJ9QqazM1r6VPEOJ7LL+uEEb73w6QCuhs89a1uv1zerOYMnsneRRwCbp
# yW11IcggU0cRKDDq1pjVJzIbIF6+oiXXbReOsgeI8zu1FyQfK0fVkaya8SmVHQ/t
# Of23mZ4W9k0Ri22QW9p3UgSC5OUDktKxxcCmGL6tXLfOGSWHIIV4YrTJTT6PNty5
# REojHJuZHArkF9VnHTERWoTjAzfI3kP+5b4alUdhgAZ7ttOu1bVnXfHaqPYl2rPs
# 20ji03LOVWsh/radgE17es5hL+t6lV0eVHrVhsssROWJuz2MXMCt7iw7lFPG9LXK
# Gjsmonn2gotGdHIuEg5JnJMJVmixd5LRlkmgYRZKzhxSCwyoGIq0PhaA7Y+VPct5
# pCHkijcIIDm0nlkK+0KyepolcqGm0T/GYQRMhHJlGOOmVQop36wUVUYklUy++vDW
# eEgEo4s7hxN6mIbf2MSIQ/iIfMZgJxC69oukMUXCrOC3SkE/xIkgpfl22MM1itkZ
# 35nNXkMolU1lAgMBAAGjggFOMIIBSjAOBgNVHQ8BAf8EBAMCAYYwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFH9ZP1Qh2q1P7wXl5qPXLQaUEggxMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# ci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2Ny
# bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0MjAx
# MV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAwTgYIKwYBBQUHMAKGQmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0MjAx
# MV8yMDExXzAzXzIyLmNydDANBgkqhkiG9w0BAQwFAAOCAgEAFJQfOChP7onn6fLI
# MKrSlN1WYKwDFgAddymOUO3FrM8d7B/W/iQ6DxXsDn7D5W4wMwYeLystcEqfkjz4
# NURRgazyMu5yRzQh4LqjA4tStTcJh1opExo7nn5PuPBYnbu0+THSuVHTe0VTTPVh
# ily/piFrDo3axQ9P4C+Ol5yet+2gTfekICS5xS+cYfSIvgn0JksVBVMYVI5QFu/q
# hnLhsEFEUzG8fvv0hjgkO+lkpV9ty6GkN4vdnd7ya6Q6aR9y34aiM1qmxaxBi6OU
# nyNl6fkuun/diTFnYDLTppOkr/mg5WSfCiDVMNCxtj4wPKC5OmHm1DQIt/MNokbb
# H3UGsFP1QbzsLocuSqLCvH09Io3fDPTmscR9Y75G4qX7RTX8AdBPo0I6OEojf39z
# uFZt0qOHm65YWQE69cZM2ueE1MB05dNNgHK9gTE7zKvK/fg8B2qjW88MT/WF5V5u
# vZGtqa9FSL2RazArA+rDPuf6JGYz4HpgMZHB4S6szWSKYBv0VisCzfxgeU+dquXW
# 9bd0auYlOB58DPcOYKdc3Se94g+xL4pcEhbB54JOgAkwYTu/9dLeH2pDqeJZAABV
# DWRQCaXfO5LgyKwKCLYXpigrZYCjUSBcr+Ve8PFWMhVTQl0v4q8J/AUmQN5W4n10
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnDMIIZvwIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEIEDfUeiWhm/bsQrJP9B7EYEKPSliTz/2OTx57ycObZ0TMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAy1PImgEl4Aqcg44m
# tRAMl1lKFC8DV8/B3ybkp7dotv8tJFb17CQb8eQbzI6wjbccECGJl96+ySj4m+uS
# lQcbPlo/U3oJCYwP1PXrJ9Mm2J7ey5xtEV8noX+KVwTQ0DYK0ybSvdqx4PJ+bKWE
# gKV4fve4QBBSJaRGd2fBgEEfuro7CwnIxcjKhy1euD0IIbm5vUje4lrNjTI5ivFk
# kwl+j7OGTU5bzBYvQNkaSv+KrBuEub7kenZbLQpxKLGhGfg1E3oM7d6NwyvzztAj
# qLoVtVX4i06ifG5tMLGecsVvqYYgA9bqcAXXBTBP72c2Z4W/yK+9u8rrT2KTDal6
# VP0KTaGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sGCSqGSIb3DQEHAqCCF2ww
# ghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCD8FUEHp6TNJIfm
# 9A3Pd4q1Xd/uVuOaEWsPSqhqCaOYrAIGavNuEqSgGBMyMDI2MTExMDIyMDUxMi44
# NDRaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RjAwMi0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHpMIIHIDCCBQigAwIBAgIT
# MwAAAiAk4ebgF7m0jgABAAACIDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTM5NTJaFw0yNzA1MTcxOTM5NTJa
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046RjAwMi0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDR
# YY7yr7ijW6CR178uKveIMufutWOicxgJwKOce/2GOQceus6ZWfX14i3jNg3JOP7M
# GJMkOAucwWBwiA8URp+ZYkGjpVoVkGZsV27WjqLwpf2AwqBsJ/TzqwE7JFFaxup3
# Ldxj8GjdJymDFRrdVN/pYHoBFrjD1IkIDu8b1CWn8tgomiKRSY+STvJq99mVkdph
# MBIUGOegQny8qRd24VME0xi8Oomks9Zq9EjDeKHGpvAbXUEQ6m3cROoEPhTE/miw
# eQH9TqJt3IOsqPv3L8urojB747XBC2y0CDIHlKLcLl3ZG8D7JXKnWTFen3msMPJp
# cvrQ3zUBVJrH/mI3RxHmCh9ppDP0uG1+PJwk6H/x+sfoG9hW64xoXkpx6DEfNZNf
# cXdKbXF28XEXdLNnzo3SLNVymeQJhNqOSKhnU84QnKmrjEk541JiurlDCkCWO9lU
# BUMb9x0nyfXUbNRPVLgP+PTMRdXOowJdYCzCQfN2ZqL0s4YI28F1Dbn7Bgw2E4P1
# E9unsvMzJHtzhS2Th3TpCfBbOGalIlF9x/DJZ/ssm/yyzT9YtIFeqmfNxBPTE3aO
# uh6HxmTICzfYAATvWNhBbo19QwsjPeA9JvhqTLC2KUNgrXroGy4eDZo0n7jFYjZk
# Uih1Ty+8E6qEvV2Na6Z5gUyD5a+tHGDmq69CmUiHfwIDAQABo4IBSTCCAUUwHQYD
# VR0OBBYEFNvInOCIhxGA8mY7l1g07UHvyNgzMB8GA1UdIwQYMBaAFJ+nFV0AXmJd
# g/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUA
# A4ICAQCtKGBto1BSvm4WFI+J0NSyVhU1LHL7F3fbjZ2d7F5Kn/FCTBZXpzrDVl63
# FLRNcIFpnJy4/nlg43r7T5sJPdo4Ms8ADSHQEJnHSu3x9UpjCzREBPi9+nHhvDgR
# x/1WmBD6gQUZJLOhcN2TxW4KJyhinMtiBFtkNRZ2vmZ1MAdNXTm5d0Lwk3wzj+/f
# 7VCCTWCXJSoqNa3VU/6sACHI97Evbnzg8bd3hxrfz6CcCVuf77egvRHinthJuwSR
# ePP7aVmcevb1nWUIAICdBebHQOrzNIeWBIQwvcFaS3SFc+49rqrwQOMFDR4FYBzS
# 7b0QeBVxFuLL2iVu4KAHMNUhLLSD4iKLDFBNTOtTzTlhGvMgG77A1cjeQrDMHa6o
# ReMDeUDqHUrxv8g7IRdIh+h0gDLkzN0xIuzli0Bv7JtybGJbV6JxaDF4CzSCIMRp
# K59nI6iKo4LgnbQBZJW7+6akYsKG/pXPlfxNv2InpD10tSCkCvw9kr6W1+NRN+Eu
# ZczRgAwWlcK9XJZ3uu/v/oxHtO7/kmVIs51F9qV6Y2QNXd6tU46YPrK98m2QDys+
# lvLNimK0e1xZ7Z1GawKohKGvlLALWDlZQqgHfJ31CB0LlIDI7iLyYTpd2iyKjqsk
# bQiyMtICH+RmH/oCg7JOK0ZA3XIMba9aSWgBF3QZ6pG3EGeQqjCCB3EwggVZoAMC
# AQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29m
# dCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIy
# NVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9
# DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2
# Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N
# 7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXc
# ag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJ
# j361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjk
# lqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37Zy
# L9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M
# 269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLX
# pyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLU
# HMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode
# 2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEA
# ATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYE
# FJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEB
# MEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# RG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEE
# AYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB
# /zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEug
# SaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9N
# aWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsG
# AQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jv
# b0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt
# 4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsP
# MeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++
# Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9
# QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2
# wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aR
# AfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5z
# bcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nx
# t67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3
# Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+AN
# uOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/Z
# cGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNMMIICNAIBATCB+aGB0aSBzjCB
# yzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMc
# TWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBU
# U1MgRVNOOkYwMDItMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCTGA9vpsJ6glqCLmI0rggGx4YE
# EqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3
# DQEBCwUAAgUA7p3sjzAiGA8yMDI2MTExMDE5MTgzOVoYDzIwMjYxMTExMTkxODM5
# WjBzMDkGCisGAQQBhFkKBAExKzApMAoCBQDuneyPAgEAMAYCAQACAS0wBwIBAAIC
# DecwCgIFAO6fPg8CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAqumAH51y
# dNP6rQob+fgkzEjPfG9T08hTTd/ARX+O2wpMXj90u+Coh5beEBOe1EkOJsR9eStk
# ztA0azDyHTNAXNqixUMPY8jILWjPrNEJ2Z7zH/T0M79GyMmT0QBQUiFL5KSKCL9X
# ZYQ6f8UfMtskM9UjZEA0ckUkDulBQjxGdXdydoaTn9EsBxOe7QEuv+drZ62hJQ8g
# oMM1tIUujHhKCysLokhi34Fp8XhmcJ8RSEnAN38VSTIjIltufyRldw/8Im2o+MEo
# FXByLDgZdqadFfARzWiip99GiuB7phfb93unYKmLyCcOosmhgrd0CHAzw/bFE4Vc
# cPn6L9zUsgzglTGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACICTh5uAXubSOAAEAAAIgMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIIm0+4pm
# rpD6Z6F5j9kIV5V5h6ZNpojt1RMvAih+XC+LMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQg43u/I6U8DVWqUSnRAhUaU13xLlhYGcqP3su5NYdI7a8wgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiAk4ebgF7m0jgAB
# AAACIDAiBCACbOCn52xwfBseNYk+llxMipNWy0jIESjJaQd9h36cMjANBgkqhkiG
# 9w0BAQsFAASCAgCT9NE1I+vd5Udmwu4XO2GEQeBoYEhzFrCs3lTnot/raQzVLnM2
# uL5BmX9E+GCPmysKodKIcnPRQJLyjyQTHMqzQtGCmMd9G1cs/SqJBzg0u5h2Kvsg
# daOR9JfGIiNu5BO/ReONve18nT49Z3JA+RY96m/57HGhoKbkeftVCe+xRrbJlrkD
# 2RuTZq0A0i3OAovMFB6uez+s63+90wgbnxv6/gcvPBsQL1aqqOuvxFCD4r5g7DOj
# 4Q9A7Krig6w1MBhcT4qcaF9m45BJyPCubdaqxHeAXws5KLgKj6J9Qc3yks9Osh6q
# 9mb8tBYr7fbtSKLpikpYR6XGDeOAHfoRIXS87/eQQwnzWb2YQUT3pCeQ5BPIrVJi
# g1fTpEvzeFJJG6lIo6i1bLJ/8N0HaYKf4dt2/MwOZ9GCY1q1TLIDvDpTYO49GwYC
# 7xMxgp95DjnRS8+HpcOi1Z9JuorM93ZO9bdbKWk+uk7y07gJlKgkX1tViVfnvDll
# SQYnnBdFiUkoCLPjWYFITCujC89KsS+vEJl74Qjq8zv8t1R2JyD5Um4vr1tC0IhO
# wlRsIXLQEjjKsiiWRsfKyyLWpAOeP/1WDdSOsgTzFG7QVR8ms9L4C8CIL8OKZZ+v
# ZEIT6K60i6nWaPu24bJTw912OE0RxCjCi+ioaz1X/nZp99ZotTpnovAOLQ==
# SIG # End signature block
