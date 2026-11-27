function Update-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619787')]
    Param
    (
        [Parameter(ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $Proxy,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $ProxyCredential,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [Switch]
        $Force,

        [Parameter()]
        [Switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $AcceptLicense,

        [Parameter()]
        [switch]
        $PassThru
    )

    Begin {
        # Change security protocol to TLS 1.2
        $script:securityProtocol = [Net.ServicePointManager]::SecurityProtocol
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Script names already tried in the current pipeline
        $scriptNamesInPipeline = @()
    }

    Process {
        $scriptFilePathsToUpdate = @()

        $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
            -Name $Name `
            -MaximumVersion $MaximumVersion `
            -RequiredVersion $RequiredVersion `
            -AllowPrerelease:$AllowPrerelease

        if (-not $ValidationResult) {
            # Validate-VersionParameters throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }

        if (-not $Name) {
            $Name = @('*')
        }

        if ($Name) {
            foreach ($scriptName in $Name) {
                $availableScriptPaths = Get-AvailableScriptFilePath -Name $scriptName -Verbose:$false

                if (-not $availableScriptPaths -and -not (Test-WildcardPattern -Name $scriptName)) {
                    $message = $LocalizedData.ScriptNotInstalledOnThisMachine -f ($scriptName, $script:MyDocumentsScriptsPath, $script:ProgramFilesScriptsPath)
                    Write-Error -Message $message -ErrorId "ScriptNotInstalledOnThisMachine" -Category InvalidOperation -TargetObject $scriptName
                    continue
                }

                foreach ($scriptFilePath in $availableScriptPaths) {
                    # Check if this script got installed with PowerShellGet
                    $installedScriptFilePath = Get-InstalledScriptFilePath -Name ([System.IO.Path]::GetFileNameWithoutExtension($scriptFilePath)) |
                    Microsoft.PowerShell.Core\Where-Object { $_ -eq $scriptFilePath }

                    if ($installedScriptFilePath) {
                        $scriptFilePathsToUpdate += $installedScriptFilePath
                    }
                    else {
                        if (-not (Test-WildcardPattern -Name $scriptName)) {
                            $message = $LocalizedData.ScriptNotInstalledUsingPowerShellGet -f ($scriptName)
                            Write-Error -Message $message -ErrorId "ScriptNotInstalledUsingPowerShellGet" -Category InvalidOperation -TargetObject $scriptName
                        }
                        continue
                    }
                }
            }
        }

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        $PSBoundParameters["InstallUpdate"] = $true

        foreach ($scriptFilePath in $scriptFilePathsToUpdate) {
            $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFilePath)

            $installedScriptInfoFilePath = $null
            $installedScriptInfoFileName = "$($scriptName)_$script:InstalledScriptInfoFileName"

            if ($scriptFilePath.ToString().StartsWith($script:MyDocumentsScriptsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsInstalledScriptInfosPath `
                    -ChildPath $installedScriptInfoFileName
            }
            elseif ($scriptFilePath.ToString().StartsWith($script:ProgramFilesScriptsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesInstalledScriptInfosPath `
                    -ChildPath $installedScriptInfoFileName

            }

            $psgetItemInfo = $null
            if ($installedScriptInfoFilePath -and (Microsoft.PowerShell.Management\Test-Path -Path $installedScriptInfoFilePath -PathType Leaf)) {
                $psgetItemInfo = DeSerialize-PSObject -Path $installedScriptInfoFilePath
            }

            # Skip the script name if it is already tried in the current pipeline
            if (-not $psgetItemInfo -or ($scriptNamesInPipeline -contains $psgetItemInfo.Name)) {
                continue
            }


            $scriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $psgetItemInfo.InstalledLocation `
                -ChildPath "$($psgetItemInfo.Name).ps1"

            # Remove the InstalledScriptInfo.xml file if the actual script file was manually uninstalled by the user
            if (-not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                Microsoft.PowerShell.Management\Remove-Item -Path $installedScriptInfoFilePath -Force -ErrorAction SilentlyContinue

                continue
            }

            $scriptNamesInPipeline += $psgetItemInfo.Name

            $message = $LocalizedData.CheckingForScriptUpdate -f ($psgetItemInfo.Name)
            Write-Verbose -Message $message

            $providerName = Get-ProviderName -PSCustomObject $psgetItemInfo
            if (-not $providerName) {
                $providerName = $script:NuGetProviderName
            }

            $PSBoundParameters["MessageResolver"] = $script:PackageManagementUpdateScriptMessageResolverScriptBlock
            $PSBoundParameters["PackageManagementProvider"] = $providerName
            $PSBoundParameters["Name"] = $psgetItemInfo.Name
            $PSBoundParameters['Source'] = $psgetItemInfo.Repository
            if ($AllowPrerelease) {
                $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
            }
            $null = $PSBoundParameters.Remove("AllowPrerelease")
            $null = $PSBoundParameters.Remove("PassThru")

            $PSBoundParameters["Scope"] = Get-InstallationScope -PreviousInstallLocation $scriptFilePath -CurrentUserPath $script:MyDocumentsScriptsPath
            $sid = PackageManagement\Install-Package @PSBoundParameters

            if ($PassThru) {
                $sid | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript }
            }
        }
    }

    End {
        # Change back to user specified security protocol
        [Net.ServicePointManager]::SecurityProtocol = $script:securityProtocol
    }
}

# SIG # Begin signature block
# MIInKgYJKoZIhvcNAQcCoIInGzCCJxcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAtUWFgz1nLr3bp
# dJMO28if+v+hZiYiETdH40iZHMFthaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KoZIhvcNAQkEMSIEIDWBTTljU/FcNB6NuHb+8t1xCUMzz942i40cChAO8h19MEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAYkvB52Gg70ccqT1o
# IKJm4Ro6aOzrumbxeZw2ID8rsyk8VU4loG40cZ2ynlYiU3EShrGF356EFfpECggu
# R3+rfGe430f4jSyhMXlH29zW3N1ygka9FtTSjsuu0Rc5hVWgftLf70RhDeDziDWn
# gnmzZoXmjN22l4e45sChgr5oQTkVWJcKqG18k75RJixgt2LbmKz+vuiJu9Ck434k
# //NnJVnvTLOUqE8csGCI+/CcoA6iR9lfT0DSmPQ3RlwyYEbqZLABA8BW85Hi+YoQ
# icogfOu00b/1GQY+HsSewUT81VEbtLblPh9Dfiz/eFVbf2QlHSc0rzulCDDm9ayi
# voYJAKGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34GCSqGSIb3DQEHAqCCF28w
# ghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDh73zCI5R5L/lY
# mu0uJPDDduEgULuK5drgyVpsiueJewIGavNLKh6jGBMyMDI2MTExMDIyMDUxOS44
# NDRaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHsMIIHIDCCBQigAwIBAgIT
# MwAAAiWAxzfGzap3SQABAAACJTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDFaFw0yNzA1MTcxOTQwMDFa
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046ODYwMy0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCm
# 8RIP0eLA46VcCPovvmqsIlN6qkmz5IsHWmUU0neUqp8uGxadeo+SwWBCwQ5alZI/
# DNdpXfyiZLZR6XYgpRPFzepIl7OCDb4NtEskJCIZDkQMNwrH9YwUyu71GGigsLIx
# eleHtA3utoVTeHjS1b8UnwORRtknKkyrUArT6ZpB2rodIcmcLcv3x3wwgYlOs0FE
# g5EsVrZb7LNc/nd0bXDp+HTOWWui8eoTVwJeLxcVP869oF8li5SU81aa2tGJ6/Js
# ejiz9JMW8SJXKBT2DCXMOUkCsGjonPZRqfvoMSIQZgtaOTyAJlrvsy0TZ78XrGqo
# ygtQimQnbOAL4KNLSCuW5TZEQGTHLOQJGgggb3j5gKC778+RIPJA+n/hmHJ/x4qT
# /HTTPoVeMCcuBKWrQXR1+/pYau3Fwe0tWIyG+LWzkRr/ZNPPupcA2Yci3qn8HR9R
# wvQopqSNJwn2Ri6am8AQyfVVy/BBw0t6jpoRPjwKvuUjfCzpae6duOxQtQ1XDN9P
# A2yl9sDko/+AXV/SOe8ea8QoQcv3s3ErkG+Lp6hnvw6OMPian4ggNkRtgtB7ro1O
# iopOUXJn9Y5EO3JUAXNcuM9m+5My1VEuvGytgAH3uxmslTnW3YbrfazaySCSSnWk
# haOZ33hgbuUQfH7n2NFEAUc/cFzfmCQUikWisnJYywIDAQABo4IBSTCCAUUwHQYD
# VR0OBBYEFLE40qoXTuMHX3AfZUu1n8nx2h93MB8GA1UdIwQYMBaAFJ+nFV0AXmJd
# g/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUA
# A4ICAQAHnfc2yUyoHZbvvyVKFuXh5HxxHIvIaR9JWpIfITJlc/Ki03juR+vckzq3
# tp5fFH5LL7eIFXRIuoewMsvWeFrWufrrW4HhmhCwkqArfA1C0xk+HaYs2O48YSxM
# X9lgS1kTTIb3YsfoFdFpKurPf2nc2Yd4wLg+FgwmkxkeyE3MUKVna8SZeVpEjnS5
# ucFck4srPwK2ORAf70I23GGyPhqgIKZphNXhSscTAQsyIqB5GwDMdRV5LK37NfU4
# YmxvCYh3TFYE/Gh01Q6yJvf9HxiEZpwW+oUk0gruHobg3sgIR5rfgUo8l30vUnaD
# YMcPAClaFMC/QbHZSaUhWXZG1OOcMp0g9vYQNLDEqFX2jlquvzVSSwtHtm1KTldC
# jRED+kdCybcPxbPalwJigXc1BsI9CitnTf0ljwb9NkZ/JVI8/D62rXXzhz4F3u0i
# VGzwncGaxRxHG/Xv4nTrpkOeepoYbNBbMWS2G1qP3Xj7pVf0+4qRyAqJ0stjQjoV
# OJImVPWRjz5PR3Dn6adQVMBJDM6gDrj1rZTFVgCtTijqGZSGzvXpGkF3vYsyE6ZD
# ma/kGdiUe5saeI6lH66PiWWXgqxt7sy2Ezv0yIjSVv+eMOT2QMUiZ6WCc7gVtAmX
# pfeIus+NmgFvM+Ic1X58e4I9EL4ZSAidSpWW0GZTLNC02mryLjCCB3EwggVZoAMC
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
# U1MgRVNOOjg2MDMtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBTb+bKOPAjCBflhzw5EXBuSWxe
# DqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3
# DQEBCwUAAgUA7p3JnjAiGA8yMDI2MTExMDE2NDkzNFoYDzIwMjYxMTExMTY0OTM0
# WjB2MDwGCisGAQQBhFkKBAExLjAsMAoCBQDuncmeAgEAMAkCAQACAUMCAf8wBwIB
# AAICEP0wCgIFAO6fGx4CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoD
# AqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAMia0
# W0LUA0ZcHRkNXEi6BPbM4ef27gJwgapu64OVHLBOiynSJdJOgO1GYRIbwu1XO8ad
# jw52bKtRmz58veiE+70WCfMx5r33Qgv57sY97sw0UHEOmhPxtBKSjiExDF8aAm+d
# rYpOQBv8x4wzPyZgkGM1uD8Cn6kDwTdsgF96xC1E5YKc8cK14mAmMwOo5bzxAhZ2
# 3i8NyLyXmUaVVqmJVHbamCVI+M4eZTBjRYHQ6ou/2GnMAHINqRlucBGC7awBfI6f
# bgZWY3WeD4E/q84yYSYo96ZCQ3Xdx5pbYJroNpcjVOMLZnDjb5Rk2BOgEa/suZCj
# +B/0VwT4grtJGlLwzTGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwAhMzAAACJYDHN8bNqndJAAEAAAIlMA0GCWCGSAFlAwQCAQUAoIIB
# SjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIMck
# xAQbR4BKj3y6+Qf3nAkl+QNJJ3ON81NTUGdKuhALMIH6BgsqhkiG9w0BCRACLzGB
# 6jCB5zCB5DCBvQQgVg3uiHo43fL3YKYCX+UXQJjCuNZZA/p0JTFqM9IcoRAwgZgw
# gYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiWAxzfGzap3
# SQABAAACJTAiBCB1UTU5YdwHebaF0bSkuLG69zPO0M2gzScV67v4MUIXmjANBgkq
# hkiG9w0BAQsFAASCAgBG2qKyMuubB9ukJKL3oPDJzybWIz4ZTB7AeCNzDhKIEwku
# KR7JXehue00n/6r4diH0mHbQrMR5P3uiclFR/duO770f2C88+Yz+gWMVx3akFwdL
# NYJvu4vLbdDb2yC+mVeHuIcIcIFhCES4juHaAVTQmyjdF3w1bZqqXETEiFTDLEbH
# xZxkmaeyKyoRPzxaH3s5cKDSMsUC28r8cUV5DKBB2CucHjG1yVhzEw6z5rCexHPP
# 3L2MawVYVB2MA7t+HoCVdRLhmJw4Ex5UvjwZPj2wdQVods1zhmqG4a9nTkImVUwp
# eTIdn/Zl/XMLoRZJbz0U30sAXa6Ny79NwT7K0+csdk1E+figQZwtMBpTmxhkKFkY
# PXsAN9uGmPi7Hn/TM+DYkrTFgpQntUbmGu0TMIaIJlD8nMfumA6kDUHM10BGCNEL
# VfcrsyvAOS1rdq2ePf97QP77JQLdOfmaNDPi2iO1W71jC8j8QOfXEIf4a+0owJZk
# qooDIaWKSCPIe4SmpemDS+OFETJmYu493PWTq8CNnJbp3uYpZ6lVa5gtpcQx7xLo
# BSMXQakMVuoWgKVZh7vndeOv3NeK3w2wSvEcubP6fYkqIK6ieM3RokKVaSOubPF4
# dztHwE7jL2ejgIKoxOxhPgnp9xPgcfDGMziL3SdawQyQ3D5pe3YSlNlccBUUCA==
# SIG # End signature block
