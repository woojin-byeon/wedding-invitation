function Test-ScriptFileInfo {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding = $false,
        DefaultParameterSetName = 'PathParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619791')]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'PathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'LiteralPathParameterSet')]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralPath
    )

    Process {
        $scriptFilePath = $null
        if ($Path) {
            $scriptFilePath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or -not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $Path `
                    -ErrorCategory InvalidArgument
                return
            }
        }
        else {
            $scriptFilePath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $LiteralPath `
                    -ErrorCategory InvalidArgument
                return
            }
        }

        if (-not $scriptFilePath.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
            $errorMessage = ($LocalizedData.InvalidScriptFilePath -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "InvalidScriptFilePath" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $scriptFilePath `
                -ErrorCategory InvalidArgument
            return
        }

        $PSScriptInfo = New-PSScriptInfoObject -Path $scriptFilePath

        [System.Management.Automation.Language.Token[]]$tokens = $null;
        [System.Management.Automation.Language.ParseError[]]$errors = $null;
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFilePath, ([ref]$tokens), ([ref]$errors))


        $notSupportedOnNanoErrorIds = @('WorkflowNotSupportedInPowerShellCore',
            'ConfigurationNotSupportedInPowerShellCore')
        $errorsAfterSkippingOneCoreErrors = $errors | Microsoft.PowerShell.Core\Where-Object { $notSupportedOnNanoErrorIds -notcontains $_.ErrorId }

        if ($errorsAfterSkippingOneCoreErrors) {
            $errorMessage = ($LocalizedData.ScriptParseError -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "ScriptParseError" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $errorsAfterSkippingOneCoreErrors `
                -ErrorCategory InvalidArgument
            return
        }

        if ($ast) {
            # Get the block/group comment beginning with <#PSScriptInfo
            $CommentTokens = $tokens | Microsoft.PowerShell.Core\Where-Object { $_.Kind -eq 'Comment' }

            $psscriptInfoComments = $CommentTokens |
            Microsoft.PowerShell.Core\Where-Object { $_.Extent.Text -match "<#PSScriptInfo" } |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $psscriptInfoComments) {
                $errorMessage = ($LocalizedData.MissingPSScriptInfo -f $scriptFilePath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "MissingPSScriptInfo" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $scriptFilePath `
                    -ErrorCategory InvalidArgument
                return
            }

            # $psscriptInfoComments.Text will have the multiline PSScriptInfo comment,
            # split them into multiple lines to parse for the PSScriptInfo metadata properties.
            $commentLines = [System.Text.RegularExpressions.Regex]::Split($psscriptInfoComments.Text, "[\r\n]")

            $KeyName = $null
            $Value = ""

            # PSScriptInfo comment will be in following format:
            <#PSScriptInfo

                .VERSION 1.0

                .GUID 544238e3-1751-4065-9227-be105ff11636

                .AUTHOR manikb

                .COMPANYNAME Microsoft Corporation

                .COPYRIGHT (c) 2015 Microsoft Corporation. All rights reserved.

                .TAGS Tag1 Tag2 Tag3

                .LICENSEURI https://contoso.com/License

                .PROJECTURI https://contoso.com/

                .ICONURI https://contoso.com/Icon

                .EXTERNALMODULEDEPENDENCIES ExternalModule1

                .REQUIREDSCRIPTS Start-WFContosoServer,Stop-ContosoServerScript

                .EXTERNALSCRIPTDEPENDENCIES Stop-ContosoServerScript

                .RELEASENOTES
                contoso script now supports following features
                Feature 1
                Feature 2
                Feature 3
                Feature 4
                Feature 5

                #>
            # If comment line count is not more than two, it doesn't have the any metadata property
            # First line is <#PSScriptInfo
            # Last line #>
            #
            if ($commentLines.Count -gt 2) {
                for ($i = 1; $i -lt ($commentLines.count - 1); $i++) {
                    $line = $commentLines[$i]

                    if (-not $line) {
                        continue
                    }

                    # A line is starting with . conveys a new metadata property
                    # __NEWLINE__ is used for replacing the value lines while adding the value to $PSScriptInfo object
                    #
                    if ($line.trim().StartsWith('.')) {
                        $parts = $line.trim() -split '[.\s+]', 3 | Microsoft.PowerShell.Core\Where-Object { $_ }

                        if ($KeyName -and $Value) {
                            if ($keyName -eq $script:ReleaseNotes) {
                                $Value = $Value.Trim() -split '__NEWLINE__'
                            }
                            elseif ($keyName -eq $script:DESCRIPTION) {
                                $Value = $Value -split '__NEWLINE__'
                                $Value = ($Value -join "`r`n").Trim()
                            }
                            else {
                                $Value = $Value -split '__NEWLINE__' | Microsoft.PowerShell.Core\Where-Object { $_ }

                                if ($Value -and $Value.GetType().ToString() -eq "System.String") {
                                    $Value = $Value.Trim()
                                }
                            }

                            ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                                -PropertyName $KeyName `
                                -PropertyValue $Value `
                                -CallerPSCmdlet $PSCmdlet
                        }

                        $KeyName = $null
                        $Value = ""

                        if ($parts.GetType().ToString() -eq "System.String") {
                            $KeyName = $parts
                        }
                        else {
                            $KeyName = $parts[0];
                            $Value = $parts[1]
                        }
                    }
                    else {
                        if ($Value) {
                            # __NEWLINE__ is used for replacing the value lines while adding the value to $PSScriptInfo object
                            $Value += '__NEWLINE__'
                        }

                        $Value += $line
                    }
                }

                if ($KeyName -and $Value) {
                    if ($keyName -eq $script:ReleaseNotes) {
                        $Value = $Value.Trim() -split '__NEWLINE__'
                    }
                    elseif ($keyName -eq $script:DESCRIPTION) {
                        $Value = $Value -split '__NEWLINE__'
                        $Value = ($Value -join "`r`n").Trim()
                    }
                    else {
                        $Value = $Value -split '__NEWLINE__' | Microsoft.PowerShell.Core\Where-Object { $_ }

                        if ($Value -and $Value.GetType().ToString() -eq "System.String") {
                            $Value = $Value.Trim()
                        }
                    }

                    ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                        -PropertyName $KeyName `
                        -PropertyValue $Value `
                        -CallerPSCmdlet $PSCmdlet

                    $KeyName = $null
                    $Value = ""
                }
            }

            $helpContent = $ast.GetHelpContent()
            if ($helpContent -and $helpContent.Description) {
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DESCRIPTION `
                    -PropertyValue $helpContent.Description.Trim() `
                    -CallerPSCmdlet $PSCmdlet

            }

            # Handle RequiredModules
            if ((Microsoft.PowerShell.Utility\Get-Member -InputObject $ast -Name 'ScriptRequirements') -and
                $ast.ScriptRequirements -and
                (Microsoft.PowerShell.Utility\Get-Member -InputObject $ast.ScriptRequirements -Name 'RequiredModules') -and
                $ast.ScriptRequirements.RequiredModules) {
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:RequiredModules `
                    -PropertyValue $ast.ScriptRequirements.RequiredModules `
                    -CallerPSCmdlet $PSCmdlet
            }

            # Get all defined functions and populate DefinedCommands, DefinedFunctions and DefinedWorkflows
            $allCommands = $ast.FindAll( { param($i) return ($i.GetType().Name -eq 'FunctionDefinitionAst') }, $true)

            if ($allCommands) {
                $allCommandNames = $allCommands | ForEach-Object { $_.Name } | Select-Object -Unique -ErrorAction Ignore
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DefinedCommands `
                    -PropertyValue $allCommandNames `
                    -CallerPSCmdlet $PSCmdlet

                $allFunctionNames = $allCommands | Where-Object { -not $_.IsWorkflow } | ForEach-Object { $_.Name } | Select-Object -Unique -ErrorAction Ignore
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DefinedFunctions `
                    -PropertyValue $allFunctionNames `
                    -CallerPSCmdlet $PSCmdlet


                $allWorkflowNames = $allCommands | Where-Object { $_.IsWorkflow } | ForEach-Object { $_.Name } | Select-Object -Unique -ErrorAction Ignore
                ValidateAndAdd-PSScriptInfoEntry -PSScriptInfo $PSScriptInfo `
                    -PropertyName $script:DefinedWorkflows `
                    -PropertyValue $allWorkflowNames `
                    -CallerPSCmdlet $PSCmdlet
            }
        }

        # Ensure that the script file has the required metadata properties.
        if (-not $PSScriptInfo.Version -or -not $PSScriptInfo.Guid -or -not $PSScriptInfo.Author -or -not $PSScriptInfo.Description) {
            $errorMessage = ($LocalizedData.MissingRequiredPSScriptInfoProperties -f $scriptFilePath)
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "MissingRequiredPSScriptInfoProperties" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $Path `
                -ErrorCategory InvalidArgument
            return
        }

        if ($PSScriptInfo.Version -match '-') {
            $result = ValidateAndGet-VersionPrereleaseStrings -Version $PSScriptInfo.Version  -CallerPSCmdlet $PSCmdlet
            if (-not $result) {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
        }

        $PSScriptInfo = Get-OrderedPSScriptInfoObject -PSScriptInfo $PSScriptInfo

        return $PSScriptInfo
    }
}

# SIG # Begin signature block
# MIInKwYJKoZIhvcNAQcCoIInHDCCJxgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBG01hzhzvVt1yT
# 8h0psjPiD2RxJVsAmEZfVUa9+/Qkk6CCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# 1cY2L4A7GTQG1h32HHAvfQESWP0xghnHMIIZwwIBATBuMFcxCzAJBgNVBAYTAlVT
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIdTRnITtcPV0gAAAAAAh0w
# DQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwLwYJ
# KoZIhvcNAQkEMSIEIKuMSbIfVP2yu9oy13ZSK89V7kWMstMIJnqHT/nf4TBnMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAmoeb8sam+mhUIH1f
# J5WodOyxzBoBakvOCVQL9JuS1PzGuAyu19HBarLaiUQaBxz0WEWxBfhnVx8KT7Dr
# dr5KzkvBvPiSeKOuCqwGGe5nZLvdtHlIr6wVAEE/bJ+cfGL8OO3gkKvLpBQBOONh
# yEmghUlr1eB3CPtsf9jkszaPsGzQDkRlVSDvpzWKt5tF+hPWmK8wS3biuSC0S4cT
# cdb58BB2HlEUBxFmfGvE1rwU72D1coimvjEhZ0zo/uphOnOPe6l5lV3kIsAnMOkg
# 9JAgVdfqMZrwi63460u1PB2DJWP3/YuaqUtvhWQg70jww20b698A2XlXNTwDh/0X
# xvfWZKGCF5cwgheTBgorBgEEAYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3Aw
# ghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCA7nPRmpmo84Bo4
# qodDWTkmhPUvK3dN8qt9Qf5FfsciUwIGavNLPgw1GBMyMDI2MTExMDIyMDUzNC41
# NzJaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzcwMy0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgIT
# MwAAAh86cGnkojAulQABAAACHzANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTM5NTFaFw0yNzA1MTcxOTM5NTFa
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046MzcwMy0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDL
# O8XFOcfGqAqgiz0+AmQmFl3dZ0aTG4UFJkqqNdMHy28DaheCBs6ONufukye5x42C
# WkzgRIy9kE2VWwEntZ8ZkgyrykC0bIqsID7+6FxguseTXf1Vwvm1D8104VmetoBJ
# lJ4uGbuyJZUvXDx55nVh50ygLTzZ24WkQsnPpvRZv2kPc39f3bhLyHVtnHsa/W/8
# 6Vrftd+AfFveA+qN/EY+XGj5c/DPMXCYECb0arYb92dDJWtwzpyBrp4gfHlgY1UE
# pc4l4AGELrf2J4wrxTzTW+SM8XhV1dOOPrYjD080IbZqL8B+IF0RCdn269YXrGK6
# QIHipznKZcCS8jN30YAHnTJVN5Zzs6t/2YsqBGDquvDad7934FFTwzvUcO3VoIyd
# 93XWwvP8/SCFVJh21W8oGQTptGHyly+Fl4henVMVZF1v6osOtirX8GFTiEhnf8nR
# dOg7yZYAJ0xy9CtDfbXaTn/cf3Lq3N/GCYKFjC+5mUCE+AJhmxMuMdvSUGmKiAFd
# iPAjUTqsWWBBZJm0eCwgeGJFmmQA+V7/98BKcE+gUL7O9eWRDQwKeAcvo6rxNv2Y
# 4jKrHA6Z/wi3a/fKUhLCNZES8qGdrpDAm7qh+6FjYxytAbkiKM6uTNy/ULPlwtlY
# ZoAJDDQP7eYCywwVbNTbHXRBSS+NccC0sSB4W7U67wIDAQABo4IBSTCCAUUwHQYD
# VR0OBBYEFNk72sGDlH0r5DwvfGR5XwJI8B7bMB8GA1UdIwQYMBaAFJ+nFV0AXmJd
# g/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUA
# A4ICAQBlbu3IoynnPz0K1iPbeNnsej2b15l5sdl2FAFBBGT9lRdc2gNV8LAIusPY
# HHhUvRDcsx4lbMNhVKPGu4TDLaqNt/CI+SFtGuqdRLpVP1XE9cCLyKrKPpcJFJCq
# PpV+efoAtYBmIUQcxxwT7WIQ7gag8+rkKvrMkCoRqKS0mKv8J1sKfi85+G2uhZ/1
# RteSVdYZOZOj+Sb4wzonTCTj7EtgMN/BX35W5dTzd7wJdGepYkVi871dSrC2Tr1Z
# FzAR7S44drCWZpJ6phJabVNOsNxFJKgSykugOGWzQ318Rr3MTPg2s3Bns+pUPVgM
# ijd4bUOH2BlEsLMMwOcolTTZqg1HYrdY1jxpUAI9ipjBQRINL/O705Z+/f2LjNmJ
# QooCVJVX24adpZ519SsfazGoqXGt91bmqKo0fI09Il4sUHh4ih6rpiQDBlyL7vmv
# CejwVxYevY4qVwTZ/o3gvl+R0lFxYS9feIM4NeG0+WsDZ7jLci5MFeuNwosQY3z2
# 6Xg1oj0U9u+ncR9uTU+xBmJ8BtlCdhQ13RNMX5P+krRYPB3XCp9Jm6XaO1995q32
# AIZm1mzBGI6yHlviXaEC5TzGiO1LXuPtXZU2X93oQJbMoe3v8+5CPKrQalGWyYuh
# 2a3V1pwbj+W0FEmEFPpu8TI+qYO1IIQWUSRvFjXth5Ob02hMMjCCB3EwggVZoAMC
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
# cGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNQMIICOAIBATCB+aGB0aSBzjCB
# yzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMc
# TWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBU
# U1MgRVNOOjM3MDMtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBLIMg1P7sNuCXpmbH2IXT2tXeE
# EKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3
# DQEBCwUAAgUA7p3JszAiGA8yMDI2MTExMDE2NDk1NVoYDzIwMjYxMTExMTY0OTU1
# WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDuncmzAgEAMAoCAQACAgC5AgH/MAcC
# AQACAhL4MAoCBQDunxszAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkK
# AwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBABAx
# Cvmuln7uF30lWgYfnuJ2nCmCEpcrAVh1Aj8fE11fLzPxutOWl8IfCORrA7BBYSCO
# rLi3CjToXVTakMh432QYcBzbGynQ64YMFwl/TaULTEz2WcvvCu5GH27svWhcRxXy
# kdpWTR8mG9g/yv9RA/g+SSKz+qS4ea9vG8XdfEIFU4vkQcAB/esfRs6TEjyZsUsL
# +n7xEbTaJrNRY/J38GTQ37ThhOS8wIxIxza34Vzk86Vd8x0L8J4kRrrLfzf1otT1
# 7QEtEPhe3d3YPBFZBdCb2IM/JzQDSVkCI13NjAjUOzkz4u1/v8RkDmac2Qk/1I+0
# YITOCNYsulNR9DwImbYxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFt
# cCBQQ0EgMjAxMAITMwAAAh86cGnkojAulQABAAACHzANBglghkgBZQMEAgEFAKCC
# AUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBa
# dzNIVvdDj/de83kwUAhAff/hp4tRruYkRXWuGbdzJjCB+gYLKoZIhvcNAQkQAi8x
# geowgecwgeQwgb0EILAkCt9WkCsMtURkFu6TY0P3UXdRnCiYuPZhe3ykLfwUMIGY
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIfOnBp5KIw
# LpUAAQAAAh8wIgQg7e2Gxg+Wp+brgnAE22vM34higJ/D8HkGk1LZTSIN7uEwDQYJ
# KoZIhvcNAQELBQAEggIAHb6GMKENamTE296vMBYb6Vh0TNwTSn3TrWk9iqVsa1o0
# dMzCRq13WifmuwNuBPUwdPPpH6PYhh/97K6UgpUmssDTZfeqXENu4haz5xdc2yNB
# AGxVrDvC6v3aKs1+XUKbsCIl8NL1cQYsH1hn6p9kwf322/zC9s1iMPRtD6295IhU
# 6m0mQCk5orwIl0FN2vPpwknJabBSfKcmR2F85EPx4H6Vbj8d4bQ8j/q6Va1Jt+dC
# kRSu5eA4gpN6pB/NI4kbx5dPo4qFxDu9TLDwYXbygQFmnsDciCncTqsRvCEHRkfP
# Mq+vnSXe9NMgkCUBJw6nNMT/BLLJWmFBT+SAwoC6irPg/yJw98UvhZ2SKn2ZkGHf
# oTkIwwhImcHdfPBlF6oxfbRS7rwEW4Wy+fgHH27NC+anJvNNWzDRUx8HG4pord3k
# sXOXSJ8JeC6EKbJ6pgsCSelWFEdDNAomq3Ye3ABMD8e6l58Zo7bIYDuXxs66E9yJ
# Cf3/OgFRalM0vRTjLkCEOXsit0sM6zORioEWs7CipviiWXt04Cbo50yTF7ZSqKoz
# wantGf9s7GG+nbehVVnmnSj+pM2fTvRI0keUIu8cDF+Tj5SWeVwi+ChnlZRJOCV3
# w3ktteMwcBut8GplwbXWXN5P2yZt0DbYN4lZ/pDC95WFtdcJUg21JdzOfbHNdvY=
# SIG # End signature block
