function Find-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398574')]
    [outputtype("PSCustomObject[]")]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [switch]
        $AllVersions,

        [Parameter()]
        [switch]
        $IncludeDependencies,

        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Filter,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Tag,

        [Parameter()]
        [ValidateNotNull()]
        [ValidateSet('DscResource', 'Cmdlet', 'Function', 'RoleCapability')]
        [string[]]
        $Includes,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $DscResource,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $RoleCapability,

        [Parameter()]
        [ValidateNotNull()]
        [string[]]
        $Command,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $AllowPrerelease
    )

    Begin {
        # Change security protocol to TLS 1.2
        $script:securityProtocol = [Net.ServicePointManager]::SecurityProtocol
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential
    }

    Process {
        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
            -Name $Name `
            -MinimumVersion $MinimumVersion `
            -MaximumVersion $MaximumVersion `
            -RequiredVersion $RequiredVersion `
            -AllVersions:$AllVersions `
            -AllowPrerelease:$AllowPrerelease

        if (-not $ValidationResult) {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeModule
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        if ($PSBoundParameters.ContainsKey("Repository")) {
            $PSBoundParameters["Source"] = $Repository
            $null = $PSBoundParameters.Remove("Repository")

            $ev = $null
            $null = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
            if ($ev) { return }
        }

        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlock

        $modulesFoundInPSGallery = @()

        # No Telemetry must be performed if PSGallery is not in the supplied list of Repositories
        $isRepositoryNullOrPSGallerySpecified = $false
        if ($Repository -and ($Repository -Contains $Script:PSGalleryModuleSource)) {
            $isRepositoryNullOrPSGallerySpecified = $true
        }
        elseif (-not $Repository) {
            $psgalleryRepo = Get-PSRepository -Name $Script:PSGalleryModuleSource `
                -ErrorAction SilentlyContinue `
                -WarningAction SilentlyContinue
            if ($psgalleryRepo) {
                $isRepositoryNullOrPSGallerySpecified = $true
            }
        }

        PackageManagement\Find-Package @PSBoundParameters | Microsoft.PowerShell.Core\ForEach-Object {

            $psgetItemInfo = New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeModule

            if ($psgetItemInfo.Type -eq $script:PSArtifactTypeModule) {
                if ($AllVersions -and -not $AllowPrerelease) {
                    # If AllVersions is specified but not AllowPrerelease, we should only return stable release versions.
                    # PackageManagement returns ALL versions (including prerelease) when AllVersions is specified, regardless of the value of AllowPrerelease.
                    # Filtering results returned from PackageManagement based on flags.
                    if ($psgetItemInfo.AdditionalMetadata -and $psgetItemInfo.AdditionalMetadata.IsPrerelease -eq 'false') {
                        $psgetItemInfo
                    }
                }
                else {
                    $psgetItemInfo
                }
            }
            elseif ($PSBoundParameters['Name'] -and -not (Test-WildcardPattern -Name ($Name | Microsoft.PowerShell.Core\Where-Object { $psgetItemInfo.Name -like $_ }))) {
                $message = $LocalizedData.MatchInvalidType -f ($psgetItemInfo.Name, $psgetItemInfo.Type, $script:PSArtifactTypeModule)
                Write-Error -Message $message `
                    -ErrorId 'MatchInvalidType' `
                    -Category InvalidArgument `
                    -TargetObject $Name
            }

            if ($psgetItemInfo -and
                $isRepositoryNullOrPSGallerySpecified -and
                $script:TelemetryEnabled -and
                ($psgetItemInfo.Repository -eq $Script:PSGalleryModuleSource)) {
                $modulesFoundInPSGallery += $psgetItemInfo.Name
            }
        }


        # Perform Telemetry if Repository is not supplied or Repository contains PSGallery
        # We are only interested in finding modules not in PSGallery
        if ($isRepositoryNullOrPSGallerySpecified) {
            Log-ArtifactNotFoundInPSGallery -SearchedName $Name -FoundName $modulesFoundInPSGallery -operationName 'PSGET_FIND_MODULE'
        }
    }

    End {
        # Change back to user specified security protocol
        [Net.ServicePointManager]::SecurityProtocol = $script:securityProtocol
    }
}

# SIG # Begin signature block
# MIInPwYJKoZIhvcNAQcCoIInMDCCJywCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDRdiOQK4qtPzAX
# fc6hU0R3V7ZY1AdP8fE9oscTsVOvB6CCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnbMIIZ1wIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEID5qDBX9blXtct3h8wEtTQ4A0a4eGUOfHF5JvxkZbCCtMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAEuZAOp3b6vGys9JL
# rdF7ms/NfYR7u2ybYzRxvgYpBrsp03gFUlbWlHF+NazP+tOr68He8IWzodbHlRl+
# t1u+I/S2DAxN/hn45cspnbmHlpMajTDq7qv7Qw0ePdEq1WtDWotLGKevVldnjFro
# aMgg/KthAcwYZnIm719uTf/wyQdW7KYJeJSR7s8gGGVxb0cx0k43sxkzPwDZPRGd
# 4WrIZs0Tc8iO8rbXYTu+Pz4Acil8+7kHjS4wPRZsndwOFhWY038kA1D8BU9ywyr1
# hTOLRqibg+gQl/i09W7mKr0DeIYM2Q13a40CoLaUsPrpVABRRjKdL24+dEDfufhe
# wwB0SaGCF6swghenBgorBgEEAYI3AwMBMYIXlzCCF5MGCSqGSIb3DQEHAqCCF4Qw
# gheAAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFE
# MIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCCreyna+EbRGpyq
# /XmLrYLtCXzJ5UHb399NneMt5bK3sgIGavNrDFNvGBIyMDI2MTExMDIyMDYxMC42
# MVowBIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR+jCCBygwggUQ
# oAMCAQICEzMAAAIzEF+3NtqoQFIAAQAAAjMwDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjYxMDE1MTgzNzQwWhcNMjgwMTEx
# MTgzNzQwWjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEt
# MCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046NkYxQS0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC8l5hSmRcLNSX1OAtiblnbTOjVi3VdcPzuwTMCzmZwYGvq
# sze6jiLl8wB+WOSKMl/BjfKl+cG49fwhhL9IqrmTerRnYHOtXMwswtMDzU482BT8
# eykyP3B38DES7PsDTAfm+K8tBY6uJshpfkR+ng4W3e9LUVLZsM0vyiOG/W/7JUpF
# fRYCZw3WPWUYqX/uqA93Z8mdAkBsxVLo2MBbXqXuAslisURP8P2CVA0C3Rmg2+02
# FZAfdPGg6+0eXdVUVmlul1ui1cx0tvTfX8NNcFVxXBwoT7Pb1nMq6X9lB/XHIFAV
# u+oRuyN4GmU6hjCUh+dmycTEK+nNreYYr0Xj1QiNHgWD3wOQ4DLXjnGSJMb+U7UB
# ZwGjmToiCeIp49J66zhNE4wQUOH39OsrtKHHg8W8tBhOw3Tzxa0gF3Wcz8BvRdY+
# UGmgok3a1UImz+3svu3uvRacd2GKo1wzsJ1QCBbCtwjJEeE18cWhHy1mZcb4PVcN
# xUPzfbAupPF+ERkNl/ow5bIUz+nvmlV2lSMwrovsFG0uqarv7eyW0aBVO4LLbc5O
# 8ozNnQyDPNIhDnv9chnLJSXpWloQFHy+PEiNV88KBJZQhIr2M1q0sUdB5kmZDRhl
# sSaEE0UZtwcj6VJetNeJUlDrlT1V2krlD6IPgZa/NOg03duyOKpEZnVyfTPSBQID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFDTcA1da+VN0e9H9+gL+81bOCZ6yMB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQBUF0lu8s2Eux08/MSGD79uQsl5EPEByxSD+em4
# 4YOrxILObuNdMKObxlMQ18DEf/aC7D+esFks57mQts+PeA8uBib2T0Y6wGGzAyLj
# yu2XpXSBvU45yRVBCQJJBfKPI6yMjMiCkh7Ge5999rA54MLm3ausyk6/HWa2pWd8
# 1kgYynKCmgaHmpsX8/vi6E25oznZQQDf5XFdR/11JQ/0uBjNjiQseucm6WRJDpAe
# LExrYiYY1iIY/t+2l7yTx2S+NsbNOi6iWOWoKoeImZiuM+XrzH2s+vf6SKUq56a9
# rDIu1DrNvRbO9IotK/ou8TwNua4B5ydtHwKMM3J4qJWqfJjthUqHzFwpca/bQxYV
# WJE2snAPrrZGYqM6uul8SL4vNNV99HsUH0hNGd+UwJuhGI8ibi6ce/vMoYUM/Z7t
# ChbXt0DLRAYYF5HjRTH/MMVTZgJEwHzQ7FRgSCanqMfTp0hZ5Hrlv/ACbbJvaHSR
# rhuBJ7vsHkv95kVGLZbBjt/sEULfoen99eQwyjlDxccQNB9C1QdZjfFEPWwKJFRP
# SD0m8D1Tb61GH9Rev6ucdb3UQhbbGqsTAsKfCtHpiqYfhUrgtJAnzn+a2sPMTTAo
# 6EFxkI+ApIVjFhNcMheDmrXF4TfZjyLUFhircZ0bu5dTu1Oc0TdZwu0jaJ1wtN3I
# G1ehmjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEw
# MB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk
# 4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9c
# T8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWG
# UNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6Gnsz
# rYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2
# LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLV
# wIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTd
# EonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0
# gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFph
# AXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJ
# YfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXb
# GjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJ
# KwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnP
# EP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMw
# UQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggr
# BgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYw
# DwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoY
# xDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# L2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYB
# BQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0B
# AQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U5
# 18JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgAD
# sAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo
# 32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZ
# iefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZK
# PmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RI
# LLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgk
# ujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9
# af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzba
# ukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/
# OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNVMIIC
# PQIBATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4D
# AhoDFQBbE8osOLFy7jKCPdFImKD+e14MFKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3pizAiGA8yMDI2MTEx
# MDE5MDU0N1oYDzIwMjYxMTExMTkwNTQ3WjBzMDkGCisGAQQBhFkKBAExKzApMAoC
# BQDunemLAgEAMAYCAQACARYwBwIBAAICD8EwCgIFAO6fOwsCAQAwNgYKKwYBBAGE
# WQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDAN
# BgkqhkiG9w0BAQsFAAOCAQEALq9YG4Y3e6cK5s4+MQaoSsomfhixIxP0ostm12pI
# SKEHaZnSDfT4dHW6XjjBlxDAraO1bcsBJBhenvcC/6qgVSd7ee/yIpBm5MGEH3zL
# YDG0tCHKVFWjS1bHae2q1HFO9R9KlM6g+eRjnTux0blneriizdKSRRlseQtShIL0
# eiG7MJUoyEdGh2AtxV0YKyA+z3bQXm9pc6xjhe/mGvnEgexNk/Tw+FaX4x0DW6TW
# Z5OhkVKF3Wci3gEaB4tySFb/eykJ5WrKQItQEB57KB6/xST1w5Wb+E9FiMmGtbR0
# Z46Dmm0+N6pWtMQFyML8sKWAGGVdZjet6dk4DWNBARbQKDGCBA0wggQJAgEBMIGT
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACMxBftzbaqEBSAAEA
# AAIzMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQ
# AQQwLwYJKoZIhvcNAQkEMSIEIH55Z5ax16aC/gVC30F14nXltqxx+JksQCFz3Rpw
# biWuMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQglrnuYgtLSF1mlNEE/1Kd
# zFC2VG+VPXvequNEQdIOOZcwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAAjMQX7c22qhAUgABAAACMzAiBCB/TTU0IcrmT2ulEZgod/cc
# P4+QGH+hCzJe6YMEItSKfDANBgkqhkiG9w0BAQsFAASCAgAgnxGAeopDUX5UXB9F
# 3dv1prkY9M/nZaEAwdrt1NPmnDLr8qjEFMFKYz+csq9HsfYDedBWBdApPc/HYGjy
# 7gUw8fkhgLXIM5DnHfiV5TU3KsigTTvzZsFr7wcwUXouS4aFE0YXK6o0KTjOwI2y
# cXOEmsiEjvY36YQo8hYRiHpZoYNCG1rLbtbJOjZetua3V1AA/0TMxLrIKvv6dmrj
# xRfiJZ96xk7upr9gWnJ9LlGgfNn/2y+IDsmwWFRDU4hq6WSRtlpr5xW2kL31PYN5
# 6Y6zsAa3yz0dv5p/oVgmzw/gDHTd5eCajbLS/eNfi4NMbYeaVfvTqlf5toJhrC4O
# mbZO+P7LBimRsIm7wxTUNkXVgZoay9qoejPm7tYxLkUQMKwwpLt2D2h+o5M57nWi
# gYI0TioibYtDbR0C5AngpWlkBw4W9VZxWr93CunEicUf0/G1yHK/unZ7PNROP0mZ
# tOzoEsIpoC9qkmSWBVO8Wjn/ZEh83osNilcpc01BWCiGO2IMrrSOoVCVMNVtaZw+
# M6yue2yEZNlQ1CbA3mq82VXehzhQbTu6aPm5EVNApEG7ZtDEk+eDWjrfBJFKI5kP
# ySrb1Q5mq1bwYiLxLOojNVHwMtLTChtLfbRfQ+1CPWILtSWRRt1D5dm1HtP5At/J
# rpDf5TyeGuRvy7qB2BRFCHuTlg==
# SIG # End signature block
