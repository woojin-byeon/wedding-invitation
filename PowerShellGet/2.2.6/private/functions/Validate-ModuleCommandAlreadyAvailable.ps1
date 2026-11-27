function Validate-ModuleCommandAlreadyAvailable
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [PSModuleInfo]
        $CurrentModuleInfo,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstallLocation,

        [Parameter()]
        [Switch]
        $AllowClobber,

        [Parameter()]
        [Switch]
        $IsUpdateOperation
    )

    <#
        Install-Module must generate an error message when there is a conflict.
        User can specify -AllowClobber to avoid the message.
        Scenario: A large module could be separated into 2 smaller modules.
        Reason 1: the consumer might have to change code (aka: import-module) to use the command from the new module.
        Reason 2: it is too confusing to troubleshoot this problem if the user isn't informed right away.
    #>
    # When new module has some commands, no clobber error if
    # - AllowClobber is specified, or
    # - Installing to the same module base, or
    # - Update operation
    if($CurrentModuleInfo.ExportedCommands.Keys.Count -and
       -not $AllowClobber -and
       -not $IsUpdateOperation)
    {
        # Remove the version folder on 5.0 to get the actual module base folder without version
        if(Test-ModuleSxSVersionSupport)
        {
            $InstallLocation = Microsoft.PowerShell.Management\Split-Path -Path $InstallLocation
        }

        $InstalledModuleInfo = Test-ModuleInstalled -Name $CurrentModuleInfo.Name
        if(-not $InstalledModuleInfo -or -not $InstalledModuleInfo.ModuleBase.StartsWith($InstallLocation, [System.StringComparison]::OrdinalIgnoreCase))
        {
            # Throw an error if there is a command with the same name from a different source.
            $CommandNames = $CurrentModuleInfo.ExportedCommands.Values.Name

            # construct a hash with all of the commands in this module.
            $CommandNameHash = @{}
            $CommandNames | % { $CommandNameHash[$_] = 1 }
            
            $AvailableCommands = Microsoft.PowerShell.Core\Get-Command  `
                                                                      -ErrorAction Ignore `
                                                                      -WarningAction SilentlyContinue |
                                    Microsoft.PowerShell.Core\Where-Object { ($CommandNameHash.ContainsKey($_.Name)) -and
                                                                             ($_.ModuleName -ne $script:PSModuleProviderName) -and
                                                                             ($_.ModuleName -ne 'PSModule') -and
                                                                             ($_.ModuleName -ne $CurrentModuleInfo.Name) }
            if($AvailableCommands)
            {
                $AvailableCommandsList = ($AvailableCommands.Name | Microsoft.PowerShell.Utility\Select-Object -Unique -ErrorAction Ignore) -join ","
                $message = $LocalizedData.ModuleCommandAlreadyAvailable -f ($AvailableCommandsList, $CurrentModuleInfo.Name)
                ThrowError -ExceptionName 'System.InvalidOperationException' `
                           -ExceptionMessage $message `
                           -ErrorId 'CommandAlreadyAvailable' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return $false
            }
        }
    }

    return $true
}
# SIG # Begin signature block
# MIInKgYJKoZIhvcNAQcCoIInGzCCJxcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA+UJcl+4d9fnKd
# RstRjHQs4c1a6NCEzNv+BsrPTEHxeaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnGMIIZwgIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEILjVaB1iDdi91IM3C3nSQd1GmjPxfcV3aDUIvp9tET9ZMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEApgEKxm5ITJowS/tV
# zA/meMAvY+yk2YMicUUz8jfkI4eEamBdd7a/uZqc3+C8AnKrVGt15RXKtgR0s7uX
# UaYRgnPybF1LNJ+4p3Uv33c2zlXJxTHF2CBK9NVLLvqB7HETaEF2eU9LJrT9UaRa
# VonpjVo33oBKN545jELRvKSJpOKm7b1+vnPv0Cs5bqfcdzDYvdd+nWqiiR5fFpft
# S6nHvo0FKNlK/reH9Pr6izNJoTdjB+90WNCMEBDS90qHm5B/daW5H4oXjIH3ebRm
# K21oTJvktnIBgC4PD0c6mRsVW9n2wpHWPiRxI6sF74irg+9RzFgMrKD1cYEp/Uwl
# ZLA80qGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34GCSqGSIb3DQEHAqCCF28w
# ghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCCxggQGEkPVfCXg
# yZBV0VlZWsmS4Y7L99DY/i1YixufoQIGavNszyDvGBMyMDI2MTExMDIyMDUyMi43
# NjRaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046N0YwMC0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHsMIIHIDCCBQigAwIBAgIT
# MwAAAh6jrKRuOW98SQABAAACHjANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTM5NDlaFw0yNzA1MTcxOTM5NDla
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046N0YwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCl
# 0TjtbDwsR7Fe8ac6ol5s1zhtTqd2AWpchQhLp9G5mmSM23N5fyQGCQ1D06rOA3Pg
# XKF+76vXvOCs2VsLv1owj4mHEyEqiq8GJ5yC+/QNYRpZPA8e7OgekzDO6S/4vy/j
# TMYbp3rhuFiKKCzTWOQtdFcF+D0k369I7pm/E07SyNMGkuNd5lj5SJ91UqFuZfjM
# B6cQ2wh77mtiRUVdj53yjdNqj+GQl+Yaz29Bjrzn7U1ln+JpLlnb0xdGmZoIPKZb
# wBVcWtyL4uyhML7SSTmiOfWXU+g+yNl0CdoLGL8LtWHEi8FsuTPeSdSqmeMrvLaE
# mibTVTS4vQQY8NPnb6uI5y6iNV9vBFcm8LU/lDTjGTqPa7UBT4gdf5Jm3wYrfCFZ
# 4P/j5MoqT0JONca50jt4TGI90SihXaDEYqk23S0IJZ3UkUpukDRTjK713BIykffx
# yBqMeQqfO0zvWfUx7BrmUpugQcw99+DxLl2gf+uQEpRmnlbrVJ9dvW9ds4fqEPN2
# jG0QwF1PBSglNcV1SpqZKitQgBGSwu/82AKztoCHwYRHRNwzwTVe/1KNTvmqAd4U
# ges4ywOH02haagT8wYY8OdWdjKn3k052w+kmc0UC0F+iVXTGZIMxvo9iBZQoXehz
# RtWJ/VOtKvCyS3csKzN7rStWJwjSWz6dtOf0l+ytLQIDAQABo4IBSTCCAUUwHQYD
# VR0OBBYEFOYKFprqBB0JZmJcFC4cPPmeF4JkMB8GA1UdIwQYMBaAFJ+nFV0AXmJd
# g/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUA
# A4ICAQCkoZB5NnJVFb5wKejRonk518a2TBNYpKcBMtfL6BS0ARaABOMGYLlPNuhI
# 1HwmelP9hX3oq3TaEm/cDkkzNQAzDedPgoRI2R7+8poNSWvHXEAs7SZODm9x7Kql
# BkNZM9ex4XY1yNmVOAmWDjRr7jKjaiQbntf7EC4GNikxGGaVWOjfYt3Q9X0r/Ks8
# KBlbzDR9zjA/TCctR4co1WpU1ZRLFrB9bl8dRxsbnyT2qQ41E7dT12R30eIGUziE
# s5GN+26V/ovXOi20dJiM13hYWvy1NNJAhkKOlLB1ONund6ffhPdUcHWsu8V+lR0a
# akMV64HqDbLumZrCNwUofVx3xMk8F4tCYJtQxLTywc30sZAD1S2sC1959x6KixA+
# p41FLUl8g64oHy3bfYnH5xd4JOBgQoaqndGjcctxr+8EknjhKyrgAzrTcKLJbUez
# goye8brCLJ+y6PAoEjpXRkSYAU8wfQ3YWRck6ALwoV7Uin8+rpGQSbXhF6c1dTFa
# kXmChClud4IADY/t6JRkJ+06FzL+jDd8KLV8Qj77JfiuTiPIG5G/xlnGoZFcX+yy
# BtDvzZE48d+Y+HYUd/cvhH1FKl7AH+5AyotqJSFmvM/BuYRx2B20asVXilV2k2Jb
# NO3LGCz3Q+dpElzwsfJrka1N/getma7fWpowsNvoIaEQvjad8TCCB3EwggVZoAMC
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
# cGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNPMIICNwIBATCB+aGB0aSBzjCB
# yzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMc
# TWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBU
# U1MgRVNOOjdGMDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCD/QNkKDIW4VIF7j3oi2qbrR0a
# /6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3
# DQEBCwUAAgUA7p3rSzAiGA8yMDI2MTExMDE5MTMxNVoYDzIwMjYxMTExMTkxMzE1
# WjB2MDwGCisGAQQBhFkKBAExLjAsMAoCBQDunetLAgEAMAkCAQACARECAf8wBwIB
# AAICEHgwCgIFAO6fPMsCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoD
# AqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAUM8v
# gW5O8NIkgzXVe1r2ZH2BUA5hz+W7l5YluBgOXO06wfpJ6VdlrIzoZKC1PttGvQJ5
# KV4L1cv9S8vJ2gfbnWkpdtTkSJyVB2tIaarKr4h27FoO08qrg9a2NMBA64+kRFzZ
# MPfiKH2BKskxMrsxjMComFLbq7+uWrXg2B9v0JJlQaOPJB905mvLiggx5UAeR/E9
# ZTRC71xLMR9wycxru7MI5vjMjhql+1L+PT72MQ+jbUst8/u3jApOPKb2xq9Oh+7t
# aS2gIL8phrRVJQh/d7QtUarIradzqfKGDESMpoYf7HJSiWX8QCplj78gUhrtqBXk
# iDnf4TgChuvHj9NwFDGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwAhMzAAACHqOspG45b3xJAAEAAAIeMA0GCWCGSAFlAwQCAQUAoIIB
# SjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEILk9
# MAeJ5qKNJAztA0LPnp+zfXQL6bnht2FPXCqb0+5lMIH6BgsqhkiG9w0BCRACLzGB
# 6jCB5zCB5DCBvQQgL4FdavP2B4yAzwG+fxurEeOEdcnb0QGLMhMjDQH284IwgZgw
# gYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAh6jrKRuOW98
# SQABAAACHjAiBCCqaFkzOaNbGYJEFKeo11k7lQh02BPq1CyvOJgTBLlyJjANBgkq
# hkiG9w0BAQsFAASCAgAN9oQ95TEnw034t3SKs/Y4Nakiet6mb+wv0/DupQc476Zk
# iw4bbp3nJyB7Xb6JAdcDMaumaJH+v52VAHHlosIa/hkXBhbOH0dWJbhugxbvl7XR
# uCIN94RoZPQzJbGPZEra+007Mw7Ri31I9WOCEWXh8izxMTdG+KPPVVzzUizac6n/
# PNnhHzQ+VPzQUTTTiBrJxzto3IGu/vpRhILwHF46D/b8DyKt8jHWc5Qq7ztuybPD
# vZALiusOLVb658Ze6zCKgI3ScKJM3eDhbevd0DrwQXAuXWvRZUQWxNjcG8b4rXh7
# HCL6Rnx/ScB4jsFAd/N6gqm7c6pmC/clbRuTc3YqHTaMq55urKmHzw2AemzY2Xcf
# oNdHj2zHUJvLVMMjM380U8WKpI0bRdZwnRoLFvEf1A7gaHyzHoUkYn+GLUxz7DsS
# OcAMlWkxxBsRSl7kvRehk70jV+deo4ipbfwBuFPAirT//OYkMW7ikDs0l0L6243w
# 07srDZTqkzUHPmTo1Xy1Q6zPGNDZ9I8TweEP21IZfoeiYvvUrqN3eBxg84K7EzAg
# byzThQvqnjl9nQOd4AN+kI8JwrsGxnAjSZPhQh4L+Djq3va0PzDTHivqWawtqrcB
# 2MPFbrmXE2hKSn8jlkHyvZyOCH63w4wZe1pvKptilKhFPd11cLvI2y/+3l6hFg==
# SIG # End signature block
