function Get-DynamicOptions
{
    param
    (
        [Microsoft.PackageManagement.MetaProvider.PowerShell.OptionCategory]
        $category
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Get-DynamicOptions'))

    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:PackageManagementProviderParam -ExpectedType String -IsRequired $false)

    switch($category)
    {
        Package {
                    Write-Output -InputObject (New-DynamicOption -Category $category `
                                                                 -Name $script:PSArtifactType `
                                                                 -ExpectedType String `
                                                                 -IsRequired $false `
                                                                 -PermittedValues @($script:PSArtifactTypeModule,$script:PSArtifactTypeScript, $script:All))
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:Filter -ExpectedType String -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:Tag -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name Includes -ExpectedType StringArray -IsRequired $false -PermittedValues $script:IncludeValidSet)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name DscResource -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name RoleCapability -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AllowPrereleaseVersions' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name Command -ExpectedType StringArray -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AcceptLicense' -ExpectedType Switch -IsRequired $false)
                }

        Source  {
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:PublishLocation -ExpectedType String -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:ScriptSourceLocation -ExpectedType String -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name $script:ScriptPublishLocation -ExpectedType String -IsRequired $false)
                }

        Install
                {
                    Write-Output -InputObject (New-DynamicOption -Category $category `
                                                                 -Name $script:PSArtifactType `
                                                                 -ExpectedType String `
                                                                 -IsRequired $false `
                                                                 -PermittedValues @($script:PSArtifactTypeModule,$script:PSArtifactTypeScript, $script:All))
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name "Scope" -ExpectedType String -IsRequired $false -PermittedValues @("CurrentUser","AllUsers"))
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AllowClobber' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'SkipPublisherCheck' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name "InstallUpdate" -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'NoPathUpdate' -ExpectedType Switch -IsRequired $false)
                    Write-Output -InputObject (New-DynamicOption -Category $category -Name 'AllowPrereleaseVersions' -ExpectedType Switch -IsRequired $false)
                }
    }
}
# SIG # Begin signature block
# MIInQwYJKoZIhvcNAQcCoIInNDCCJzACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA7vT1Qj7RDgwj0
# F/nc960xAZbR47xGa2RLEoBeAeBQY6CCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnfMIIZ2wIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEINdiDC60yzkGYU4ujylx19J+YMJWJDld5NvQrrou6EhJMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAXKva0WOUZM3i+62H
# PF3MTXx3YCH+W5qOnvtbJLFvF9GcgKL+IaU5vKDzkc7cV0IxYDTldMz1ayHwf+qf
# WsgTF8jlFboQSlbDdGPoaoi36v9ZfoMAgv9hKsEy5hhFCOjhBXqjvPUHzLeJkYUs
# et9nJR8OMXAdPyJnWU99xnGnnRDI38mnIDvOozifSHoCkS80YnJh9WqQajhKd1tG
# pUFdCUC+GhNIPUI95ohTa49MxO0g5EI3BVv3FwECJ48VjFdoKzVAIS2UpO2jAznL
# x6Dy65IFmMGDVCLPlLvHERFFQjoLBX8CSVxHkqLy+IBE9s3BBfuH8NF+TQew8YwO
# m6I/16GCF68wgherBgorBgEEAYI3AwMBMYIXmzCCF5cGCSqGSIb3DQEHAqCCF4gw
# gheEAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFF
# MIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDHxZ1xjImJlOdx
# rUUGP4TL4BfuEAKnAKfgNGGKj920cQIGavNMnvXtGBMyMDI2MTExMDIyMDYwOC40
# NjlaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MzFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf0wggcoMIIF
# EKADAgECAhMzAAACNZsWed5GYdQrAAEAAAI1MA0GCSqGSIb3DQEBCwUAMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI2MTAxNTE4Mzc0M1oXDTI4MDEx
# MTE4Mzc0M1owgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# LTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjQzMUEtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAvA2sNh2bPpbdonwoPppQdy7rBQU2AYvZmVhKyXoLox21
# OwvocY4P+BvqLOAtL67cWoekZxO9MMZ66lvqROg6EI8fsWbHn+OT/RYZps9h4drA
# IPhiE3fUzjwVM3XdZ90VvxutuVbCaj0z2xAbfGJnC1emXUNnZ/1BR85NvWen44bC
# rJYtghstvh4So+UpUZg2ZdVDpR1n7spqnkG5hJBwK1pSom46V/SwisMIhfcY7Ie8
# 9Na9TJ5S47U1Nwf9JWEdrFLsCwrnh+65fAdfOzGy9oBdjSn/HEBE4H/7mgHIO+vk
# x2/q2TRWjNdSIi2Sj+THCRPZe+c+LBM925/pncGt42JE/gH1QcAKtF6x0sLIh9yy
# UfJZom5ZiD5s4aq/QDxEQZLA1UcWHIqFc5z+Aartxjre04B3bvwiVC6C5Yt7yxgz
# ZHsQlLsOoVKPwS2fO2yA5XWNEKpuomBjICT9owmvSW/dpVGSwbypHDZt5kWO3PrN
# iOTjpQXijznyE5bXFi9JlQF5Bm/BaF2Sxg7sLHstgxpP5SYoRoBjOPLqVWqtQfGE
# G7G1qxJL0YfaFnhWM8U0M90oQvV5jeGwAYq+ArsvGsYAV8r2po/xCK8R7eaNTzL5
# cjPzt23S0AO224NZnGmqm5G/QXVQOX3YI/NvqSoH6kYUmqmx6n22W9B7vq9jGYUC
# AwEAAaOCAUkwggFFMB0GA1UdDgQWBBQwSUMAYtxdCS9tvQtArQCayL3kLDAfBgNV
# HSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBU
# aW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwG
# CCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRz
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDANBgkqhkiG9w0BAQsFAAOCAgEApX6cT9hL8p3gSnGdvnoPm07DiccGrmj2SFZY
# aPRyraviUBiKmjVy3jLXKQT0Mfbzkf8zfm5l2kr0YFQ9JW/LB/zt4p4cIVCAe+Ed
# oxIJVzTGeLDkHDcvmZqhIFeh33uPrbtX9HQc5QU5TpOWute7AfohT6tqTblNLlz5
# OLKVKFEJBQGFh/Mnw2t9ZLeCm4Gf1DeZ1sWNft/rHbzkwudXBh280BFKVG3AoyHb
# OMo3W5GwAyVq7IAAI39QcThuYKxNHPoVrL36WHcyfjk9eIDz6GMQhOoWI7MdgQHr
# 0jOf9UQHWhN0jG6pBMKnfgPWFXUL6XlHCGYROaETJVxpzmmKQblHmWmnCTYNWb0Q
# PWiQb5ZNNYD+zWI6KcpsGcRC6cYITgwYw+OfjejWV4wQW6V5mvN7e87RSMMjcMtR
# Foy8FULlM8l/B6hlnFiBbrCO24X57A0SO1TTFPn3dSx/37bjhI9ABaHuiGZlDe9I
# jsEVLTzfOdE59i9ZhooyUsO/ceSZp4x0Icw3PJzq1r4/1AOlG8mQDbCsddauUM6n
# 8VSfq8rBJCdqdrcWpRqUerFnyAp0S+97C0YfBsaVpXUGVBPfqF+KwKlGGjxP32s3
# qcUiTM8Mqt1OwRbp66d6k4/8XXLPrfqx1StgUwDjd/N8vzMPFj1pDYt1GiVXwjKN
# NvnRei8wggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3
# DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIw
# MAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAx
# MDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# 5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/
# XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1
# hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7
# M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3K
# Ni1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy
# 1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF80
# 3RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQc
# NIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahha
# YQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkL
# iWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV
# 2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIG
# CSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUp
# zxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBT
# MFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYI
# KwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGG
# MA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186a
# GMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsG
# AQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcN
# AQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1
# OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYA
# A7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbz
# aN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6L
# GYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3m
# Sj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0
# SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxko
# JLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFm
# PWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC482
# 2rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7
# vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWDCC
# AkACAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MzFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsO
# AwIaAxUAWss3eoS1rlla0gVyedUYK2xMzzCggYMwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO6dyxcwIhgPMjAyNjEx
# MTAxNjU1NTFaGA8yMDI2MTExMTE2NTU1MVowdjA8BgorBgEEAYRZCgQBMS4wLDAK
# AgUA7p3LFwIBADAJAgEAAgEBAgH/MAcCAQACAhDgMAoCBQDunxyXAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMB
# hqAwDQYJKoZIhvcNAQELBQADggEBAD8Hw+a3q4BbBohaZ4hk1aRCGwWQXRAj1dk9
# u8H+n+Rnm76eJJBfy4KjhNMka+cQoBXD4zh9tWD6Cu8z8QgXATA8r9AR9A5bJ6fP
# 8kj8KKVzRkPFvYPH3199ghlFePEmTu52DPDpqbMey1bgegtKIrqKmoU2cAWTaRmN
# XbFbLmwgPdrj0PasETmwSe01OcqZbj4tRMDeK4RANctT42jhgaRip9R5t3ckK502
# rMdCIllQAG0ZWRfh2M89ANZAvf+e3OQ7DZg/YX8NH4/r27hmUOGcTQKmng/Bjde2
# /sj5m6ESmzgdwK5g6WOZiahFEUtGk3mCuqvnPJqBFZLv82ekzQExggQNMIIECQIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAjWbFnneRmHU
# KwABAAACNTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCDXXxt1vT4vH2yQm7GIEUNS/hBCS3QW6Ivz
# U06RqcOkUDCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EILSmuCosvR8n9AW8
# ugAmM+QpgoFN9j6qphrP9k5KcxDKMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTACEzMAAAI1mxZ53kZh1CsAAQAAAjUwIgQgmSlUIZtvKKAPtI6P
# lTKAHVjqS0/m2bYipUeX/HZyvcMwDQYJKoZIhvcNAQELBQAEggIACQOlUKaAzbJU
# VkXurUJTgkolqfEMjYQw0Fdf3bwj9MllnxsDllA0zfqvBYtnKHnCV1ZHKRK91Ntx
# uhq5R6oJWzp8q0J73zHO8FTWb5EuXrNZmLFzwvAGOhih/cT1GgOTkNgugKcrfPTb
# Cv3q2+LBp4gFz/O8ivpxn/F7dZ4lBY/ELjtodzL3cjEtI9tI5ptJ6pvYaufcpVSw
# vBFI51Dh5pUNmAUQwRurPcezWfB42m/SowOHSIs6JXuwqSNDAz4TlCCW/Fn2TDrh
# jUciJQVHdYVpV7bY+IJD8yvGP7amqgZZq3Sr947okKCn0Z5NBL+WkpbcTrlrvbom
# PGprliANeDqbLgR3ku0bD4Ndgiw+sLjiHxmdoz80IEBEggPe19LZgcbf/zpNniSM
# iPG7XopAfc72C8vOz4TxpEEzrpWq9tfhdx1CCr0bj7dmDjzO6BS4rxWV3IE/t8Ni
# qBgDx50ZGzRBCDDonxfTvhKuwJi8KKE/gxoJuP/s/t6iVCDuKV1fw5/WyIsJQNKQ
# 6HqES+Tn7LR6BGvKBz3Nq1tr92czgpMxDirW21pfmySqPcHJxAEsW1bsxp6rNZ3O
# z5FMHUFdw9Zaq0+5P3qW+BoddcQvRU6ZKtfr0vDuFl7rr/MnuIEaz+/TeipWBizR
# 8CPvTdFx7Aj1OowiS6MLF31JvVb5d1U=
# SIG # End signature block
