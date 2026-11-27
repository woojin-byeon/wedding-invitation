function Find-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619785')]
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
        [ValidateSet('Function', 'Workflow')]
        [string[]]
        $Includes,

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

        $PSBoundParameters['Provider'] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")

        if ($PSBoundParameters.ContainsKey("Repository")) {
            $PSBoundParameters["Source"] = $Repository
            $null = $PSBoundParameters.Remove("Repository")

            $ev = $null
            $repositories = Get-PSRepository -Name $Repository -ErrorVariable ev -verbose:$false
            if ($ev) { return }

            $RepositoriesWithoutScriptSourceLocation = $false
            foreach ($repo in $repositories) {
                if (-not $repo.ScriptSourceLocation) {
                    $message = $LocalizedData.ScriptSourceLocationIsMissing -f ($repo.Name)
                    Write-Error -Message $message `
                        -ErrorId 'ScriptSourceLocationIsMissing' `
                        -Category InvalidArgument `
                        -TargetObject $repo.Name `
                        -Exception 'System.ArgumentException'

                    $RepositoriesWithoutScriptSourceLocation = $true
                }
            }

            if ($RepositoriesWithoutScriptSourceLocation) {
                return
            }
        }

        $PSBoundParameters["MessageResolver"] = $script:PackageManagementMessageResolverScriptBlockForScriptCmdlets

        $scriptsFoundInPSGallery = @()

        # No Telemetry must be performed if PSGallery is not in the supplied list of Repositories
        $isRepositoryNullOrPSGallerySpecified = $false
        if ($Repository -and ($Repository -Contains $Script:PSGalleryModuleSource)) {
            $isRepositoryNullOrPSGallerySpecified = $true
        }
        elseif (-not $Repository) {
            $psgalleryRepo = Get-PSRepository -Name $Script:PSGalleryModuleSource `
                -ErrorAction SilentlyContinue `
                -WarningAction SilentlyContinue
            # And check for IsDefault?
            if ($psgalleryRepo) {
                $isRepositoryNullOrPSGallerySpecified = $true
            }
        }

        PackageManagement\Find-Package @PSBoundParameters | Microsoft.PowerShell.Core\ForEach-Object {
            $psgetItemInfo = New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript

            if ($psgetItemInfo.Type -eq $script:PSArtifactTypeScript) {
                if ($AllVersions -and -not $AllowPrerelease) {
                    # If AllVersions is specified but not AllowPrerelease, we should only return stable release versions.
                    # PackageManagement returns ALL versions (including prerelease) when AllVersions is specified, regardless of the value of AllowPrerelease.
                    # Filtering results returned from PackageManagement based on flags.
                    if ($psgetItemInfo.AdditionalMetadata -and $psgetItemInfo.AdditionalMetadata.IsPrerelease -eq $false) {
                        $psgetItemInfo
                    }
                }
                else {
                    $psgetItemInfo
                }
            }
            elseif ($PSBoundParameters['Name'] -and -not (Test-WildcardPattern -Name ($Name | Microsoft.PowerShell.Core\Where-Object { $psgetItemInfo.Name -like $_ }))) {
                $message = $LocalizedData.MatchInvalidType -f ($psgetItemInfo.Name, $psgetItemInfo.Type, $script:PSArtifactTypeScript)
                Write-Error -Message $message `
                    -ErrorId 'MatchInvalidType' `
                    -Category InvalidArgument `
                    -TargetObject $Name
            }

            if ($psgetItemInfo -and
                $isRepositoryNullOrPSGallerySpecified -and
                $script:TelemetryEnabled -and
                ($psgetItemInfo.Repository -eq $Script:PSGalleryModuleSource)) {
                $scriptsFoundInPSGallery += $psgetItemInfo.Name
            }
        }

        # Perform Telemetry if Repository is not supplied or Repository contains PSGallery
        # We are only interested in finding artifacts not in PSGallery
        if ($isRepositoryNullOrPSGallerySpecified) {
            Log-ArtifactNotFoundInPSGallery -SearchedName $Name -FoundName $scriptsFoundInPSGallery -operationName PSGET_FIND_SCRIPT
        }
    }

    End {
        # Change back to user specified security protocol
        [Net.ServicePointManager]::SecurityProtocol = $script:securityProtocol
    }
}

# SIG # Begin signature block
# MIInRAYJKoZIhvcNAQcCoIInNTCCJzECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDKhaNpu1c4U0QF
# dmJ1vxzn/jJ/BqwTd9lBEy7ikAKl9aCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghngMIIZ3AIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEIHBFYbKN5WL4NTkSgk0jy8NRTlFOnL2rrMOOzW5DvQS2MEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAjFQzHby4j/vnBQCE
# Waew0w79NSvF0LMj/Hv/itnhIMFUt4dpwa9krb7y635GuRARLBU4XIJprysvygfg
# pAJu3VujQCzrHdQZY+yljb8RlJhMrYP7699a5NvlZ3BhqsGPnf943ymjd6y93Lij
# fUWBjrZyjDMK8cUQSs0dqZ7uFm6jXLUBUhiLqZd9NVdTfrZBNwVe/pGlDZC6AWaw
# KBOMo92HbqE/PiGQVqAf6/GITF4ZLmKPGSDRFy8jT+7yQnzE7EXTZIT19u5sQz5H
# hQfv5siPgRxjWZRwVL4wOVjzna3bMTasRFbaJoZ0RJA0l+QtKp6in3NW+hB80X4m
# Fgh3JKGCF7AwghesBgorBgEEAYI3AwMBMYIXnDCCF5gGCSqGSIb3DQEHAqCCF4kw
# gheFAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFF
# MIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCA9jwQ+YNbKJjCG
# 6zJEkx5KYcdq98NUMhtburHd0PGQEwIGavNo0od5GBMyMDI2MTExMDIyMDU1NS40
# MTVaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjoyRDFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf4wggcoMIIF
# EKADAgECAhMzAAACN6Qdd0mCnHcGAAEAAAI3MA0GCSqGSIb3DQEBCwUAMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI2MTAxNTE4Mzc0NloXDTI4MDEx
# MTE4Mzc0NlowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# LTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjJEMUEtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEAszNbmuzfKciH9SLDWQDQ9yVseAl1rHad7QC/zdHEBQR+
# aZ9cWJ384M4c+8oOBczU3ccEAuWGlK1bLsf9uMAUGdqtehE98QSnGlkOZ4aY1Zg8
# xarJbA5aS7uYm6Ezj4sJGFIZfvY7Yubvi9cYAbTuO9vMv2COEDzbQdEWA9plbugq
# ewJ87bHzWRQdecBQgbT0EMR2tIE8SfIC+UQWLqNNh8ICnDsPVVtT72pBJBhmih6z
# +AH5W6aq26FQ/nRDifA0xn/MAf+yYi09AvsqOFm6co0qpkREfyxVoADVfW/6m8lz
# h3MtOsv3v7skCcJaYYl5P/Tr5LL9hmAAhvJzXFKJ1xJfa5xNXB/5eCFpOBXos1sW
# IbEXSVCG0YimOflUfD7FXSdwr6TFHiKMi1n1swNGxPSJ/g1FkAmOPuP4vB+pyHr1
# 8rB0D8Z7xkhOfG3W0CF8kncdM5h+xCNJv/u4gOUj4ddazy7Aufi73hIjBYTLex+L
# wC0shNMFBPY0I68IWn5M58xLd8vKH3tW+4kkyYrYl9OpdqdaQFcpzH8FmMRf0H3z
# dJvWsot9iLg8r1coMkp6VjeNI04kzWg0kjRq1yz1dO5QW/cFOyeKNIeGw3PaEpy7
# fK8Dnnl5h+xpllOU1eXNck0148WO0r757orPD0psSQVNeL8VDi5LwOvp/k2AVgcC
# AwEAAaOCAUkwggFFMB0GA1UdDgQWBBRZmI/sEPTenZlqCN70CVGEgtnDxDAfBgNV
# HSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBU
# aW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwG
# CCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRz
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDANBgkqhkiG9w0BAQsFAAOCAgEAc6waDB7TBHE+3qefxRhVfwck3ga4MyGisXiO
# Fe+BzJUuQAsQQ7LIOyMgoo73/2vWUEc/iktuaML0buf7UABr5IJugtjcJ8a25ppR
# Et7BkfEluJ0pKzpSNyoFeO01Jw4ODUEJ5smmuaENf2YNJ1aXiKnCVwZi2kkzxr1V
# Cxk9Az8O2eFLMXMJyxwoFJJz5J2LklbAB/f/CtIVMIMHCDdEmCnRg/kTvDasd9Ux
# +UqwSYyt6jzfq+JI9iads3kCYk+BB/izrdGQdGFvXgatE0bRfguxZs7DuoMOEjek
# W2ClqGfMF5gMxDYO9QTlF7WAZY1vcg3adICghgwvn/yBMr9idOAxr/O6rV3WZ2fK
# 2VibCyBfvVjsdwqBpd7V3E659nHGtq2hrhH6JHhoHWvnEDZr70bQEcmU68hkqZu/
# frHGR3TwKo9+X7qSmxMyF4fQp8Sxrd/0MKTQnR8jEzhw6/i/XVBSMAWKK6M+huPi
# el0rQLzCDT+JkvisF9N6FCIwGAlvHTZqDPE5MDG4DKdgZ2UQvdruPeLIajpf6N09
# qBIfAntZHzsVT6Ramzwn8fmF/eiCsuXaA5fToSjxZRgSGBQgobJ4AIyatsFTMSt1
# 9kVlgbV9Deycfd43rrc7f7GXwdsy3QU3U7PmDKrXyblKVIZOHaGeNuXQzFqMw3Do
# xNYyo6QwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3
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
# vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWTCC
# AkECAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjoyRDFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsO
# AwIaAxUA74B+BZVincdKNDfX/wQ7r43ctXiggYMwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO6d51EwIhgPMjAyNjEx
# MTAxODU2MTdaGA8yMDI2MTExMTE4NTYxN1owdzA9BgorBgEEAYRZCgQBMS8wLTAK
# AgUA7p3nUQIBADAKAgEAAgIDawIB/zAHAgEAAgITqTAKAgUA7p840QIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBCwUAA4IBAQA55TH8tX+JkkKBTAm78iRaapS1h84strOp
# WB1MC33hb+Md7dQfOZ3fvIKv29SDaFf3F2qEM7my2v1weWsO5OyKRQR2OOFEMEU8
# TYBAUAyqAEJORCCzl9X4fJi29tpdVbh6WRRdEmeLHbIg6ThP41plAldYcrNIkh0T
# Fqcu2JTBF23pWvmPRJKi8tIk+oGdV1ivqpUfsnLvA6h053UZzkHfnglB/wsDowS9
# fFruFVTiChdOSfalkjx72ROjugK2mnoA7pu/34bO2J2UETVUiYvn8UDtPG7UiRBS
# 9eoN+wEAziGFnsltlxPUpTC+LvbIuxFLOqynhJSwsUND1DEzcd3PMYIEDTCCBAkC
# AQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAI3pB13SYKc
# dwYAAQAAAjcwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG
# 9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgungJSSWPtVNJ4Ed/F83QB48o1r308Vru
# MAFDaMWjxKIwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCBQT0oArWPGTDfO
# HeKTKAbqzK9WDbGwLQrUj33wter19TCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwAhMzAAACN6Qdd0mCnHcGAAEAAAI3MCIEIDI8ts7N+28T4AC7
# SOwTvB7L2HppFUm8kU8skJjEuUxFMA0GCSqGSIb3DQEBCwUABIICAGtEjbkBvh0o
# izN13Clgqnu/CveCoVTXLk92P9n7GUz+MeD3/DdpRXg6Tr2m/hc4UWxKNXYupaHa
# 4+5GTaz0bnGfdzILInKpjBkdoJZ2AqIIV/CgdljtFOQtu651LqzAI660M9Qd77ot
# sV1nmnyKdtOw0hvhEwvp4GlrghvpqGgOpB2yB7+edxaDtztSmjGFUFIKyl7RnNuP
# vyQ/o1d4FCoxlVAee3WLRpF5z2BdukOCQrvlnHz9yM7tMKyoVhPyPpOrneSsz5UF
# 6wDiIiOgNfg+tXpqto4fN2076jmhAFQ4DuxdOM39Hywn5+xG1Ho/uy1ip3XbnRIF
# +kzb5b1ToWvySa8YLgXSFr223p2mB4tzERLCutIanuuDxmetopL68Rds+W8o47Gn
# Rf9UOrfgnIBlxKKEyXh8jH5GWLtb+Y8TNbK50ep4YhZiVvIHDhrgmcQDIUld2/1W
# XUkzGSO04pSHl7F+0Mx9QZc1HQklGAaEcxI6rgcVoSBOBmUUBJCZAFpeLSw4UIls
# +9kFLbl+9KqYyRVW3aR/OXCl6oh1VAkBnBesth/FCKn9eimZfm/kRqZW+nMk8TPp
# +edLSY1Gn8L46RSru4BKAZto2G5SVFzu5bsxw45oRP/784yh42VyzOEsbLWyeXHO
# bhqx5hZ1x3ROJDbwGjTS/Bg3Fd1Bu0fL
# SIG # End signature block
