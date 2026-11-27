function Update-ScriptFileInfo {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(PositionalBinding = $false,
        DefaultParameterSetName = 'PathParameterSet',
        SupportsShouldProcess = $true,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619793')]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'PathParameterSet',
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'LiteralPathParameterSet',
            ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string]
        $LiteralPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

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

    Process {
        # Resolve the script path
        $scriptFilePath = $null
        if ($Path) {
            $scriptFilePath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or
                -not (Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $Path)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $Path `
                    -ErrorCategory InvalidArgument
            }
        }
        else {
            $scriptFilePath = Resolve-PathHelper -Path $LiteralPath -IsLiteralPath -CallerPSCmdlet $PSCmdlet |
            Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $scriptFilePath -or
                -not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $scriptFilePath -PathType Leaf)) {
                $errorMessage = ($LocalizedData.PathNotFound -f $LiteralPath)
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $errorMessage `
                    -ErrorId "PathNotFound" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ExceptionObject $LiteralPath `
                    -ErrorCategory InvalidArgument
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

        # Obtain script info
        $psscriptInfo = $null
        try {
            $psscriptInfo = Test-ScriptFileInfo -LiteralPath $scriptFilePath
        }
        catch {
            if (-not $Force) {
                throw $_
                return
            }
        }

        if (-not $psscriptInfo) {
            if (-not $Description) {
                ThrowError  -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $LocalizedData.DescriptionParameterIsMissingForAddingTheScriptFileInfo `
                    -ErrorId 'DescriptionParameterIsMissingForAddingTheScriptFileInfo' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
                return
            }

            if (-not $Version) {
                $Version = '1.0'
            }
            else {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $Version -CallerPSCmdlet $PSCmdlet
                if (-not $result) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
            }

            if (-not $Author) {
                if ($script:IsWindows) {
                    $Author = (Get-EnvironmentVariable -Name 'USERNAME' -Target $script:EnvironmentVariableTarget.Process -ErrorAction SilentlyContinue)
                }
                else {
                    $Author = $env:USER
                }
            }

            if (-not $Guid) {
                $Guid = [System.Guid]::NewGuid()
            }
        }
        else {
            # Use existing values if any of the parameters are not specified during Update-ScriptFileInfo
            if (-not $Version -and $psscriptInfo.Version) {
                $Version = $psscriptInfo.Version
            }

            if (-not $Guid -and $psscriptInfo.Guid) {
                $Guid = $psscriptInfo.Guid
            }

            if (-not $Author -and $psscriptInfo.Author) {
                $Author = $psscriptInfo.Author
            }

            if (-not $CompanyName -and $psscriptInfo.CompanyName) {
                $CompanyName = $psscriptInfo.CompanyName
            }

            if (-not $Copyright -and $psscriptInfo.Copyright) {
                $Copyright = $psscriptInfo.Copyright
            }

            if (-not $RequiredModules -and $psscriptInfo.RequiredModules) {
                $RequiredModules = $psscriptInfo.RequiredModules
            }

            if (-not $ExternalModuleDependencies -and $psscriptInfo.ExternalModuleDependencies) {
                $ExternalModuleDependencies = $psscriptInfo.ExternalModuleDependencies
            }

            if (-not $RequiredScripts -and $psscriptInfo.RequiredScripts) {
                $RequiredScripts = $psscriptInfo.RequiredScripts
            }

            if (-not $ExternalScriptDependencies -and $psscriptInfo.ExternalScriptDependencies) {
                $ExternalScriptDependencies = $psscriptInfo.ExternalScriptDependencies
            }

            if (-not $Tags -and $psscriptInfo.Tags) {
                $Tags = $psscriptInfo.Tags
            }

            if (-not $ProjectUri -and $psscriptInfo.ProjectUri) {
                $ProjectUri = $psscriptInfo.ProjectUri
            }

            if (-not $LicenseUri -and $psscriptInfo.LicenseUri) {
                $LicenseUri = $psscriptInfo.LicenseUri
            }

            if (-not $IconUri -and $psscriptInfo.IconUri) {
                $IconUri = $psscriptInfo.IconUri
            }

            if (-not $ReleaseNotes -and $psscriptInfo.ReleaseNotes) {
                $ReleaseNotes = $psscriptInfo.ReleaseNotes
            }

            if (-not $PrivateData -and $psscriptInfo.PrivateData) {
                $PrivateData = $psscriptInfo.PrivateData
            }
        }

        $params = @{
            Version                    = $Version
            Author                     = $Author
            Guid                       = $Guid
            CompanyName                = $CompanyName
            Copyright                  = $Copyright
            ExternalModuleDependencies = $ExternalModuleDependencies
            RequiredScripts            = $RequiredScripts
            ExternalScriptDependencies = $ExternalScriptDependencies
            Tags                       = $Tags
            ProjectUri                 = $ProjectUri
            LicenseUri                 = $LicenseUri
            IconUri                    = $IconUri
            ReleaseNotes               = $ReleaseNotes
            PrivateData                = $PrivateData
        }

        # Ensure no fields contain '<#' or '#>' (would break comment section)
        if (-not (Validate-ScriptFileInfoParameters -parameters $params)) {
            return
        }

        if ("$Description" -match '<#' -or "$Description" -match '#>') {
            $message = $LocalizedData.InvalidParameterValue -f ($Description, 'Description')
            Write-Error -Message $message -ErrorId 'InvalidParameterValue' -Category InvalidArgument

            return
        }

        $PSScriptInfoString = Get-PSScriptInfoString @params

        $requiresStrings = Get-RequiresString -RequiredModules $RequiredModules

        $DescriptionValue = if ($Description) { $Description } else { $psscriptInfo.Description }
        $ScriptCommentHelpInfoString = Get-ScriptCommentHelpInfoString -Description $DescriptionValue

        $ScriptMetadataString = $PSScriptInfoString
        $ScriptMetadataString += "`r`n"

        if ("$requiresStrings".Trim()) {
            $ScriptMetadataString += "`r`n"
            $ScriptMetadataString += $requiresStrings -join "`r`n"
            $ScriptMetadataString += "`r`n"
        }

        $ScriptMetadataString += "`r`n"
        $ScriptMetadataString += $ScriptCommentHelpInfoString
        $ScriptMetadataString += "`r`nParam()`r`n`r`n"

        $tempScriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Get-Random).ps1"

        try {
            # First create a new script file with new script metadata to ensure that updated values are valid.
            Microsoft.PowerShell.Management\Set-Content -Value $ScriptMetadataString -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

            $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

            if (-not $scriptInfo) {
                # Above Test-ScriptFileInfo cmdlet writes the error
                return
            }

            $scriptFileContents = Microsoft.PowerShell.Management\Get-Content -LiteralPath $scriptFilePath

            # If -Force is specified and script file doesnt have a valid PSScriptInfo
            # Prepend the PSScriptInfo and Check if the Test-ScriptFileInfo returns a valid script info without any errors
            if ($Force -and -not $psscriptInfo) {
                # Add the script file contents to the temp file with script metadata
                Microsoft.PowerShell.Management\Set-Content -LiteralPath $tempScriptFilePath `
                    -Value $ScriptMetadataString, $scriptFileContents `
                    -Force `
                    -WhatIf:$false `
                    -Confirm:$false

                $tempScriptInfo = $null
                try {
                    $tempScriptInfo = Test-ScriptFileInfo -LiteralPath $tempScriptFilePath
                }
                catch {
                    $errorMessage = ($LocalizedData.UnableToAddPSScriptInfo -f $scriptFilePath)
                    ThrowError  -ExceptionName 'System.InvalidOperationException' `
                        -ExceptionMessage $errorMessage `
                        -ErrorId 'UnableToAddPSScriptInfo' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ExceptionObject $scriptFilePath `
                        -ErrorCategory InvalidOperation
                    return
                }
            }
            else {
                [System.Management.Automation.Language.Token[]]$tokens = $null;
                [System.Management.Automation.Language.ParseError[]]$errors = $null;
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptFilePath, ([ref]$tokens), ([ref]$errors))

                # Update PSScriptInfo and #Requires
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

                # Ensure that metadata is replaced at the correct location and should not corrupt the existing script file.

                # Remove the lines between below lines and add the new PSScriptInfo and new #Requires statements
                # ($psscriptInfoComments.Extent.StartLineNumber - 1)
                # ($psscriptInfoComments.Extent.EndLineNumber - 1)
                $tempContents = @()
                $IsNewPScriptInfoAdded = $false

                for ($i = 0; $i -lt $scriptFileContents.Count; $i++) {
                    $line = $scriptFileContents[$i]
                    if (($i -ge ($psscriptInfoComments.Extent.StartLineNumber - 1)) -and
                        ($i -le ($psscriptInfoComments.Extent.EndLineNumber - 1))) {
                        if (-not $IsNewPScriptInfoAdded) {
                            $PSScriptInfoString = $PSScriptInfoString.TrimStart()
                            $requiresStrings = $requiresStrings.TrimEnd()

                            $tempContents += "$PSScriptInfoString `r`n`r`n$($requiresStrings -join "`r`n")"
                            $IsNewPScriptInfoAdded = $true
                        }
                    }
                    elseif ($line -notmatch "\s*#Requires\s+-Module") {
                        # Add the existing lines if they are not part of PSScriptInfo comment or not containing #Requires -Module statements.
                        $tempContents += $line
                    }
                }

                Microsoft.PowerShell.Management\Set-Content -Value $tempContents -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

                $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

                if (-not $scriptInfo) {
                    # Above Test-ScriptFileInfo cmdlet writes the error
                    return
                }

                # Now update the Description value if a new is specified.
                if ($Description) {
                    $tempContents = @()
                    $IsDescriptionAdded = $false

                    $IsDescriptionBeginFound = $false
                    $scriptFileContents = Microsoft.PowerShell.Management\Get-Content -Path $tempScriptFilePath

                    for ($i = 0; $i -lt $scriptFileContents.Count; $i++) {
                        $line = $scriptFileContents[$i]

                        if (-not $IsDescriptionAdded) {
                            if (-not $IsDescriptionBeginFound) {
                                if ($line.Trim().StartsWith(".DESCRIPTION", [System.StringComparison]::OrdinalIgnoreCase)) {
                                    $IsDescriptionBeginFound = $true
                                }
                                else {
                                    $tempContents += $line
                                }
                            }
                            else {
                                # Description begin has found
                                # Skip the old description lines until description end is found

                                if ($line.Trim().StartsWith("#>", [System.StringComparison]::OrdinalIgnoreCase) -or
                                    $line.Trim().StartsWith(".", [System.StringComparison]::OrdinalIgnoreCase)) {
                                    $tempContents += ".DESCRIPTION `r`n$($Description -join "`r`n")`r`n"
                                    $IsDescriptionAdded = $true
                                    $tempContents += $line
                                }
                            }
                        }
                        else {
                            $tempContents += $line
                        }
                    }

                    Microsoft.PowerShell.Management\Set-Content -Value $tempContents -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false

                    $scriptInfo = Test-ScriptFileInfo -Path $tempScriptFilePath

                    if (-not $scriptInfo) {
                        # Above Test-ScriptFileInfo cmdlet writes the error
                        return
                    }
                }
            }

            if ($Force -or $PSCmdlet.ShouldProcess($scriptFilePath, ($LocalizedData.UpdateScriptFileInfowhatIfMessage -f $Path) )) {
                Microsoft.PowerShell.Management\Copy-Item -Path $tempScriptFilePath -Destination $scriptFilePath -Force -WhatIf:$false -Confirm:$false

                if ($PassThru) {
                    $ScriptMetadataString
                }
            }
        }
        finally {
            Microsoft.PowerShell.Management\Remove-Item -Path $tempScriptFilePath -Force -WhatIf:$false -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
}

# SIG # Begin signature block
# MIInJwYJKoZIhvcNAQcCoIInGDCCJxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDIS5fd3fJVRDGg
# npXRxNWRCFSJsAvK2Z9tS2nMTtSKbqCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KoZIhvcNAQkEMSIEIJVkk+8D3HJcJVw2GwnhFfWVVM8eRl288UQ5zHCFzx7SMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAFkFhnLdCgGG/ndxj
# ZCiFUzBj9jrpbXLL+AjKcvrNfYMk476oJb68A18zavSZUnTgoshtNu7b7XUXy40v
# XuuHgHCWth/o26pEGKM78mmJ+AOfoE20m0auw95J+eLta4/Su80NTj3ICl3lgM67
# yQ0ZqY2T0cYQO43Ai6nwD1vrD+0m5PJP9Bd8Fq1+v9d5+KKjO+xIS4ml8zmi5MUi
# c9M/cilc5sjo9knDWEmEwBpv6BZCqkZORtD/v0TKQoNVCh/QFp+iMFiN0wLTHU1X
# ojs109y7H8DVYPp5YyTvB992Y5k3zsnIogCUomPjdpaMljimHakQkzTgkx3krx8B
# 0QEMv6GCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sGCSqGSIb3DQEHAqCCF2ww
# ghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCBTC7FjtPoX1+03
# ZxJkutdkhMTc0guoP3H/muEi1mhS+QIGavNtm9PKGBMyMDI2MTExMDIyMDUyMS44
# NzZaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTYwMC0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHpMIIHIDCCBQigAwIBAgIT
# MwAAAiY1tD5nQ5P2HwABAAACJjANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDJaFw0yNzA1MTcxOTQwMDJa
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046OTYwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/
# /w+ZZIL5RFFpVI8D3ZyuNu8IzcAEOD30OLYjh337rXjcrIlOSzpJc4ZeUxEyli6x
# 6F6zm4NR8dbPb9diDp/hOUzHWGxiA1Z3RXKBb/4F/ojyvN43SEGWqSfVc3I3BlsY
# T35ecVAJ9kVf90YOv29tFjJBBZkYvrT/DwwyRLscOyP4p+9/lyJjD+ULs3YXBhVr
# fZ+MbQB+BYKLqRvBKbj/wR9akNrMxQINoGaD5jZO/N/nSsmG2P1zv/cv4gSoMBnW
# eQIBkjd2I5w1DeXupp2vSiNmR5sA2ZkBK3yiQWaJvRxODlkfiyHk9Mkk/TrYTjmj
# PCbhe+uqhHNRy8UlbOvWsCq0tRtUykHv39DgqAfJNrE8OSt835rBzDprrcAhwmgf
# hoVi4AKeqwikY0nUa48K0Qy80XT4fiEA3ExEZNaRFo9Nq/GwbfgqKqGmc9xhKuRF
# cjtua4KHZvnAvpWgEFSOCkovXs/BcLnkEHM9xZ8iUag5CyhNqXYYE/z0pcXdYaNI
# kQ68EWmuvLm7g9oofV2vOm5GVNoghnkWG6nGPo/JwEgmA9oSS0EfvFRMWPA/gpSv
# F3shArKHnaEpVSSi3DNbyiuYiEs9Ko0IkZc8xKFeQRaqGRxrB+2r/7B3X81Tps99
# KhFwg+wD87od22F2MUg1x7twt3gaVnFk0IZIwUPCGwIDAQABo4IBSTCCAUUwHQYD
# VR0OBBYEFF3hn9fYJN2Y/Z9LVbBPIxAzXHsQMB8GA1UdIwQYMBaAFJ+nFV0AXmJd
# g/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6
# Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUA
# A4ICAQA2Ux0tr9sYCjsq0FRyiVpx15OurNXv6Qk7iX+ArVPlz3w4tqjcTNm1dt3t
# Tua2wJMpJhPH8n7UXhmT98d5Du44Ll4adnse4SQfVg3QL6aRkXHnJUn8y9iftB/P
# y22n9xnwPFfj3QlDOSgLuHleu97U0iH2ZaluYabWXJihdiYpK8cPHFlqZOAiot0+
# GD8dP+RMuvpxt/F2LmYelpoZwriiFOUmlxEUV7xJHyZZlDquskeyuq01DTv91N4q
# M8cfPPhl/2pc4HeMf/nd2HouifJbDQFNd4WPhLzn0Sy3u1Zh3+S3tjQdqN+dyw60
# RaV+RXCoOLgFZ3MAg/GoDl+fvb5hy/1a71ctX8wEad1Pf6def2pqfl3wFc++hkF8
# DXXTZofJN4YVaN3InwbAGQDDkNK4lqecCixxmSKwidPynGeE5OtvNoK1pkLsm/i8
# F1RjGczZ/kSF2VDkqG866iQ+jVbGOQ6Du3eyyFcFKZoDJ4B5mEAS9aT2SKqllLey
# bOboH6r67siR5B/2Hnu7+KYuYZy0BEadtA6ngG4cnSR9JsrkhhsKmb11ujqwgJyN
# x92MsoGGwNgN1aI0QID8CsjCFwpfmMzlA44xHKYv3hmjxeqBS4uU5rQeiAnVgpJe
# aVGKm/lzPDtnppGV+7XhRp5b1ZxT/Z7Xxc+I7H7/jCtQDZoaZTCCB3EwggVZoAMC
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
# U1MgRVNOOjk2MDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCi/fMxFtkqr7XMXdsRyWU0lSKH
# Z6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3
# DQEBCwUAAgUA7p3sGDAiGA8yMDI2MTExMDE5MTY0MFoYDzIwMjYxMTExMTkxNjQw
# WjBzMDkGCisGAQQBhFkKBAExKzApMAoCBQDunewYAgEAMAYCAQACAQAwBwIBAAIC
# Dx8wCgIFAO6fPZgCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEAW1yJXNyP
# BO7AXgZqCfPhxuqSnPocC8Y6PMBNFseyN2Ql7/2JtEP3IMpcL7odaAEzZSLYZbdP
# ozTn3The63JAHC1yL6sF3NGYcVzhpE6mPwS13dtZ4xdgD1GzsK9JGudOpHdaJnXo
# cL9zJgXUAN2wJOAiD+wL8ddo9a+dJxWoRg2OLlUV8ML3VPIbZL83QUA8kq05+D0N
# HYC9/3nxrd7uTgZJbyEtggKl5uSuE7VG8oxKGRh0x/+3A8d1uh7l1cMkDM/bqfe3
# bAy8kmhro4UyZW/1CXmIZXFFHvFQ6V5bDXD2xpRNPxNdpxYkUnw7OK7mkZjLpWhL
# 1izqFkryQzjF/DGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAACJjW0PmdDk/YfAAEAAAImMA0GCWCGSAFlAwQCAQUAoIIBSjAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIPJstv2T
# imnsJvKfSp4g7JiIDp18gz7RK46WsSjn2vkTMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQgzDJcYWdM2xlEGuzoY38FtXSiRo0/dUFiosWNSwWduCowgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiY1tD5nQ5P2HwAB
# AAACJjAiBCArqEOPvSz4m0kSkDyNoz4Cc7jcRfe6OInHN5wLrolYCDANBgkqhkiG
# 9w0BAQsFAASCAgBTYb53rqe1CiGeuCuIFiTzS2HjykMzI0CJe9G0a7E0kgfkzyyD
# KF5QfSzGKtdyc8sSbTuGMFfMCZDS3cEoQdRfkX8txsm2nMWUI8ix976Rlol9+w6U
# s56jDXGjTmBwxlT/l1kAiT1SHD5z3qRi47Xr0gsnRu8d86E7vl1OH7K/H8asDKuT
# OBnpx4whR4NRahtC8isfQlwkrJ+2DS2ZmCBgYY6+WHC8KFajmsLCkV3VH1nt+iZZ
# VJO89P7yO3PV0zGtWZfDwQHRbOanu2P3yLyG6b1TcZCW8z441X1HmjLK9fw7dAiA
# Kgv+AMiCtmg8lu6NlEkJp0UmlFY3V+u35Mr2FXMjxuKsILD+pzESp/da1X+PLYP8
# mbAxX0RpErTUF1cKgba8GE2FcEnt2tkbcF20qCvk1wTfKRhwbTzoCRVcvai3UTvD
# phAbKoVO25sLsP66sFpiDh1tU+mEUS6aUww2x4faevflfn+6/uXrtpqTq4qLeb3D
# /1ZlZ52E1JmI12xCwOz7PbJ/HZggcW0FEwIdgkp2/5PcxOGjN40a70gsCzbhG+py
# hlNx0KDPLvO7TbYBOqY2GTMy0WgJh5+HaMiFn/9+8SIMvSVXQxJwPBaYrALjcUup
# 9uZWhrcsy3cuF4bGWf3pBeaU5VaI6st5Qy9SIgxtBNgUthL9DATBK8Nl1Q==
# SIG # End signature block
