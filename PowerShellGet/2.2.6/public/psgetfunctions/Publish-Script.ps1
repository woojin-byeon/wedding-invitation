function Publish-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        PositionalBinding = $false,
        DefaultParameterSetName = 'PathParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619788')]
    Param
    (
        [Parameter(Mandatory = $true,
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
        $LiteralPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $NuGetApiKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository = $Script:PSGalleryModuleSource,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $Force
    )

    Begin {
        # Change security protocol to TLS 1.2
        $script:securityProtocol = [Net.ServicePointManager]::SecurityProtocol
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force:$Force
    }

    Process {
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

        if ($Repository -eq $Script:PSGalleryModuleSource) {
            $repo = Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if (-not $repo) {
                $message = $LocalizedData.PSGalleryNotFound -f ($Repository)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'PSGalleryNotFound' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Repository
                return
            }
        }
        else {
            $ev = $null
            $repo = Get-PSRepository -Name $Repository -ErrorVariable ev
            # Checking for the $repo object as well as terminating errors are not captured into ev on downlevel PowerShell versions.
            if ($ev -or (-not $repo)) { return }
        }

        $DestinationLocation = $null

        if (Get-Member -InputObject $repo -Name $script:ScriptPublishLocation) {
            $DestinationLocation = $repo.ScriptPublishLocation
        }

        if (-not $DestinationLocation -or
            (-not (Microsoft.PowerShell.Management\Test-Path -Path $DestinationLocation) -and
                -not (Test-WebUri -uri $DestinationLocation))) {
            $message = $LocalizedData.PSRepositoryScriptPublishLocationIsMissing -f ($Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PSRepositoryScriptPublishLocationIsMissing" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        $message = $LocalizedData.PublishLocation -f ($DestinationLocation)
        Write-Verbose -Message $message

        if (-not $NuGetApiKey.Trim()) {
            if (Microsoft.PowerShell.Management\Test-Path -Path $DestinationLocation) {
                $NuGetApiKey = "$(Get-Random)"
            }
            else {
                $message = $LocalizedData.NuGetApiKeyIsRequiredForNuGetBasedGalleryService -f ($Repository, $DestinationLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "NuGetApiKeyIsRequiredForNuGetBasedGalleryService" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
            }
        }

        $providerName = Get-ProviderName -PSCustomObject $repo
        if ($providerName -ne $script:NuGetProviderName) {
            $message = $LocalizedData.PublishScriptSupportsOnlyNuGetBasedPublishLocations -f ($DestinationLocation, $Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PublishScriptSupportsOnlyNuGetBasedPublishLocations" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        if ($Path) {
            $PSScriptInfo = Test-ScriptFileInfo -Path $scriptFilePath
        }
        else {
            $PSScriptInfo = Test-ScriptFileInfo -LiteralPath $scriptFilePath
        }

        if (-not $PSScriptInfo) {
            # Test-ScriptFileInfo throws the actual error
            return
        }

        $scriptName = $PSScriptInfo.Name

        $result = ValidateAndGet-VersionPrereleaseStrings -Version $PSScriptInfo.Version -CallerPSCmdlet $PSCmdlet
        if (-not $result) {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }
        $scriptVersion = $result["Version"]
        $scriptPrerelease = $result["Prerelease"]
        $scriptFullVersion = $result["FullVersion"]

        # Copy the source script file to temp location to publish
        $tempScriptPath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Get-Random)" |
        Microsoft.PowerShell.Management\Join-Path -ChildPath $scriptName

        $null = Microsoft.PowerShell.Management\New-Item -Path $tempScriptPath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        if ($Path) {
            Microsoft.PowerShell.Management\Copy-Item -Path $scriptFilePath -Destination $tempScriptPath -Force -Recurse -Confirm:$false -WhatIf:$false
        }
        else {
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $scriptFilePath -Destination $tempScriptPath -Force -Recurse -Confirm:$false -WhatIf:$false
        }

        try {
            $FindParameters = @{
                Name            = $scriptName
                Repository      = $Repository
                Tag             = 'PSModule'
                AllowPrerelease = $true
                Verbose         = $VerbosePreference
                ErrorAction     = 'SilentlyContinue'
                WarningAction   = 'SilentlyContinue'
                Debug           = $DebugPreference
            }

            if ($Credential) {
                $FindParameters[$script:Credential] = $Credential
            }

            # Check if the specified script name is already used for a module on the specified repository
            # Use Find-Module to check if that name is already used as module name
            $modulePSGetItemInfo = Find-Module @FindParameters |
            Microsoft.PowerShell.Core\Where-Object { $_.Name -eq $scriptName } |
            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore
            if ($modulePSGetItemInfo) {
                $message = $LocalizedData.SpecifiedNameIsAlearyUsed -f ($scriptName, $Repository, 'Find-Module')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedNameIsAlearyUsed" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $scriptName
            }

            $null = $FindParameters.Remove('Tag')

            $currentPSGetItemInfo = $null
            $currentPSGetItemInfo = Find-Script @FindParameters |
            Microsoft.PowerShell.Core\Where-Object { $_.Name -eq $scriptName } |
            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if ($currentPSGetItemInfo) {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $currentPSGetItemInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $galleryScriptVersion = $result["Version"]
                $galleryScriptPrerelease = $result["Prerelease"]
                $galleryScriptFullVersion = $result["FullVersion"]

                if ($galleryScriptFullVersion -eq $scriptFullVersion) {
                    $message = $LocalizedData.ScriptVersionIsAlreadyAvailableInTheGallery -f ($scriptName,
                        $scriptFullVersion,
                        $galleryScriptFullVersion,
                        $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId 'ScriptVersionIsAlreadyAvailableInTheGallery' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation
                }

                if ($galleryScriptVersion -eq $scriptVersion -and -not $Force) {
                    # Prerelease strings will not both be null, otherwise would have terminated already above

                    if (-not $Force -and (-not $galleryScriptPrerelease -and $scriptPrerelease)) {
                        # User is trying to publish a new Prerelease version AFTER publishing the stable version.
                        $message = $LocalizedData.ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString -f ($scriptName,
                            $scriptVersion,
                            $scriptPrerelease,
                            $galleryScriptPrerelease,
                            $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                    }

                    # elseif ($galleryScriptPrerelease -and -not $scriptPrerelease) --> allow publish
                    # User is attempting to publish a stable version after publishing a prerelease version (allowed).

                    elseif ($galleryScriptPrerelease -and $scriptPrerelease) {
                        # if ($galleryScriptPrerelease -eq $scriptPrerelease) --> not reachable, would have terminated already above.

                        if (-not $Force -and ($galleryScriptPrerelease -gt $scriptPrerelease)) {
                            # User is trying to publish a lower prerelease version.
                            $message = $LocalizedData.ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString -f ($scriptName,
                                $scriptVersion,
                                $scriptPrerelease,
                                $galleryScriptPrerelease,
                                $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName "System.InvalidOperationException" `
                                -ExceptionMessage $message `
                                -ErrorId "ScriptPrereleaseStringShouldBeGreaterThanGalleryPrereleaseString" `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation
                        }

                        # elseif ($galleryScriptPrerelease -lt $scriptPrerelease) --> allow publish
                        # User is trying to publish a newer prerelease version (allowed)
                    }
                }
                elseif (-not $Force -and (Compare-PrereleaseVersions -FirstItemVersion $scriptVersion `
                            -FirstItemPrerelease $scriptPrerelease `
                            -SecondItemVersion $galleryScriptVersion `
                            -SecondItemPrerelease $galleryScriptPrerelease)) {
                    $message = $LocalizedData.ScriptVersionShouldBeGreaterThanGalleryVersion -f ($scriptName,
                        $scriptVersion,
                        $galleryScriptVersion,
                        $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "ScriptVersionShouldBeGreaterThanGalleryVersion" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation
                }

                # else ($galleryScriptVersion -lt $scriptVersion) --> allow publish
                # User is trying to publish a newer stable version (allowed)
            }

            $shouldProcessMessage = $LocalizedData.PublishScriptwhatIfMessage -f ($PSScriptInfo.Version, $scriptName)
            if ($Force -or $PSCmdlet.ShouldProcess($shouldProcessMessage, "Publish-Script")) {
                $PublishPSArtifactUtility_Params = @{
                    PSScriptInfo     = $PSScriptInfo
                    NugetApiKey      = $NuGetApiKey
                    Destination      = $DestinationLocation
                    Repository       = $Repository
                    NugetPackageRoot = $tempScriptPath
                    Verbose          = $VerbosePreference
                    WarningAction    = $WarningPreference
                    ErrorAction      = $ErrorActionPreference
                    Debug            = $DebugPreference
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $PublishPSArtifactUtility_Params.Add('Credential', $Credential)
                }
                Publish-PSArtifactUtility @PublishPSArtifactUtility_Params
            }
        }
        finally {
            Microsoft.PowerShell.Management\Remove-Item $tempScriptPath -Force -Recurse -ErrorAction Ignore -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }

    End {
        # Change back to user specified security protocol
        [Net.ServicePointManager]::SecurityProtocol = $script:securityProtocol
    }
}

# SIG # Begin signature block
# MIInOQYJKoZIhvcNAQcCoIInKjCCJyYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAa3aaHsMx+Ot0w
# UAvbnp36sz/S0/EoAGM+TtAe/9laZqCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
# xZvoL37EAAAAAAIcMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAlVTMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBD
# b2RlIFNpZ25pbmcgUENBIDIwMjQwHhcNMjYwNDE2MTg1OTQxWhcNMjcwNDE1MTg1
# OTQxWjB0MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYD
# VQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDVsZfgOKmM31HPfoWOoNEiw0SlCiIxUMC0I9NMWbucKOw/e9lP
# oAoehQVu6SG65V4EPzrYsnBnFPNoi4/HoOdjhz1qkrEt4I6tEcxXU6oOeY9zGveC
# /3iBeuhLYxM3M/PkcUoebF+Nednm8OkdSPoDu8imViHPQq/8CQUu0WRR4rE+dMRf
# rpVqfmNi2qWCX94T4MsepijGVkwE//tJg0ryAiYdHT34LSnlG/RSBZmQRGWZ5g8j
# qnKjRParSqMft1gvjuUTVgtWNZfgcLFSK5Wa0myrq8OPcgTGGsRgun+tnSS+IxDT
# xVsAPH1OzvPjwomguByhUe/OcvUN0D5Wmp7xAgMBAAGjggGqMIIBpjAOBgNVHQ8B
# Af8EBAMCB4AwHwYDVR0lBBgwFgYKKwYBBAGCN0wIAQYIKwYBBQUHAwMwHQYDVR0O
# BBYEFNoH7a2YDjOSwpkp6DHcmUS7J+0yMFQGA1UdEQRNMEukSTBHMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxFjAUBgNVBAUT
# DTIzMDAxMis1MDc1NjkwHwYDVR0jBBgwFoAUf1k/VCHarU/vBeXmo9ctBpQSCDEw
# YAYDVR0fBFkwVzBVoFOgUYZPaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9w
# cy9jcmwvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmclMjBQQ0ElMjAyMDI0LmNy
# bDBtBggrBgEFBQcBAQRhMF8wXQYIKwYBBQUHMAKGUWh0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwQ29kZSUyMFNpZ25pbmcl
# MjBQQ0ElMjAyMDI0LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IC
# AQAUnEqhaRXe0T3hIJjvdQErEkrA/7bByjn6t5IArODkkRjzkYwtKMc2yYj2quaN
# rLutWw2YZcngKPy1b71YyDJQTy4NDRwaSh9Tw5thrk3NmcPrAHia5vtcBJ1CgtKK
# 7mQbIcQ22d/N3813ayCDDFewu1+jsZmX+r/aTEqaOM4TVxVtRSkuCy8nAXKuChOK
# Li/zA4XuH8iEYqIsj2YoNaeSxVmeGiERXpKdo3dDmYi0kO5w2D8VS4c3+9h6gElY
# BaAAg/dYErBg27qT3vv0zRDJhJufvCNylA8S7/+8H5E/PV5cng6na9VV/w9OV3qu
# uND6zdGa2EX38Glp50F9AIQk3p2xXmcvorDeM4XJ7UlWYBi6g80J1SSOQnInCYFE
# msfUNn3+1AaTJKSJL83quKArTac2pKhu0Yzzzrzo6HrsRiQKzpnRBb1/dMa6P3hz
# 75XbMRBctNsFhZC07WCmjExdLg2eHW5uV0TY8D5+6wozJf7vF3+WHkYPO85Z+BC6
# U4FkNbYNycZ9cE4j1tXRdyDCfml6c0HWPHjNVDObrv9lKt3qUqFpX38VCqVCyNOO
# 1UcXfQiVjJw32U2WUKZjt/neJKHEBsm9kFsLuWzkQ53+qcaSaytmsCnk2gOglrlD
# 5d3kKyvvAw+rzm0lT8K38P6PLxfZQHhu4W8dV7Av8N2ZmDCCBr0wggSloAMCAQIC
# EzMAAAA5O7Y3Gb8GHWcAAAAAADkwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBS
# b290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDExMB4XDTI0MDgwODIwNTQxOFoX
# DTM2MDMyMjIyMTMwNFowVzELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQ
# Q0EgMjAyNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANgBnB7jOMeq
# lRYHNa265v4IY9fH8TKhemHfPINe1gpLaV3dhg324WwH06LcHbpnsBukCDNitryo
# 0dtS/EW6I/yEL/bLSY8hKpbfQuWusBPr9qazYcDxCW/qnjb5JsI1s8bNOg3bVATv
# QVL4tcf03aTycsz8QeCdM0l/yHRObJ9QqazM1r6VPEOJ7LL+uEEb73w6QCuhs89a
# 1uv1zerOYMnsneRRwCbpyW11IcggU0cRKDDq1pjVJzIbIF6+oiXXbReOsgeI8zu1
# FyQfK0fVkaya8SmVHQ/tOf23mZ4W9k0Ri22QW9p3UgSC5OUDktKxxcCmGL6tXLfO
# GSWHIIV4YrTJTT6PNty5REojHJuZHArkF9VnHTERWoTjAzfI3kP+5b4alUdhgAZ7
# ttOu1bVnXfHaqPYl2rPs20ji03LOVWsh/radgE17es5hL+t6lV0eVHrVhsssROWJ
# uz2MXMCt7iw7lFPG9LXKGjsmonn2gotGdHIuEg5JnJMJVmixd5LRlkmgYRZKzhxS
# CwyoGIq0PhaA7Y+VPct5pCHkijcIIDm0nlkK+0KyepolcqGm0T/GYQRMhHJlGOOm
# VQop36wUVUYklUy++vDWeEgEo4s7hxN6mIbf2MSIQ/iIfMZgJxC69oukMUXCrOC3
# SkE/xIkgpfl22MM1itkZ35nNXkMolU1lAgMBAAGjggFOMIIBSjAOBgNVHQ8BAf8E
# BAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFH9ZP1Qh2q1P7wXl5qPX
# LQaUEggxMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBP
# oE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAw
# TgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDANBgkqhkiG9w0BAQwFAAOC
# AgEAFJQfOChP7onn6fLIMKrSlN1WYKwDFgAddymOUO3FrM8d7B/W/iQ6DxXsDn7D
# 5W4wMwYeLystcEqfkjz4NURRgazyMu5yRzQh4LqjA4tStTcJh1opExo7nn5PuPBY
# nbu0+THSuVHTe0VTTPVhily/piFrDo3axQ9P4C+Ol5yet+2gTfekICS5xS+cYfSI
# vgn0JksVBVMYVI5QFu/qhnLhsEFEUzG8fvv0hjgkO+lkpV9ty6GkN4vdnd7ya6Q6
# aR9y34aiM1qmxaxBi6OUnyNl6fkuun/diTFnYDLTppOkr/mg5WSfCiDVMNCxtj4w
# PKC5OmHm1DQIt/MNokbbH3UGsFP1QbzsLocuSqLCvH09Io3fDPTmscR9Y75G4qX7
# RTX8AdBPo0I6OEojf39zuFZt0qOHm65YWQE69cZM2ueE1MB05dNNgHK9gTE7zKvK
# /fg8B2qjW88MT/WF5V5uvZGtqa9FSL2RazArA+rDPuf6JGYz4HpgMZHB4S6szWSK
# YBv0VisCzfxgeU+dquXW9bd0auYlOB58DPcOYKdc3Se94g+xL4pcEhbB54JOgAkw
# YTu/9dLeH2pDqeJZAABVDWRQCaXfO5LgyKwKCLYXpigrZYCjUSBcr+Ve8PFWMhVT
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghnGMIIZwgIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIBu6LXu1M65PrGvnRjgohxhTXHM0
# jjyy9/BJ+Rm6kJNfMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAZl3wFlIHRynqEmxlJ/jI2RgYlQk+oi6CKDkHgMz+hpMpON2GH0Egf0kRrpNh
# 4nXOXDwzTs3oc0hNKEs8nCPY6naU2e9IFvCvqdAcVRSwe3Mfl+Z6L+yS2lKVbnXS
# EX3B+Oc7YXYcS7TNIubiBkPuewRq/ZUWx8yk/NEWkl6ap5RrIgM3pD6dpKIjSDjY
# 4Wu9aEGatg+gRQAqWIF5nPEUOxWiW+PXg7xbiLn9jPPxVPRejB2gRwVbs5lFs7Vm
# +dtFEUPwctag89pMN1y2/qcVEwJNcsE/iIwTsQTAcD7zykiE/+fP2KbILyQzuhvZ
# W+bvlOS7X+u8TJvGzPnwaygk3KGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34G
# CSqGSIb3DQEHAqCCF28wghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCB7h7EjohDHAtjSVcnbA5psOc9NYATGT5QWyqNRJVWjHQIGavNLKiHKGBMy
# MDI2MTExMDIyMDU0MC4xMjVaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHs
# MIIHIDCCBQigAwIBAgITMwAAAiWAxzfGzap3SQABAAACJTANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDFa
# Fw0yNzA1MTcxOTQwMDFaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCm8RIP0eLA46VcCPovvmqsIlN6qkmz5IsHWmUU0neUqp8u
# Gxadeo+SwWBCwQ5alZI/DNdpXfyiZLZR6XYgpRPFzepIl7OCDb4NtEskJCIZDkQM
# NwrH9YwUyu71GGigsLIxeleHtA3utoVTeHjS1b8UnwORRtknKkyrUArT6ZpB2rod
# IcmcLcv3x3wwgYlOs0FEg5EsVrZb7LNc/nd0bXDp+HTOWWui8eoTVwJeLxcVP869
# oF8li5SU81aa2tGJ6/Jsejiz9JMW8SJXKBT2DCXMOUkCsGjonPZRqfvoMSIQZgta
# OTyAJlrvsy0TZ78XrGqoygtQimQnbOAL4KNLSCuW5TZEQGTHLOQJGgggb3j5gKC7
# 78+RIPJA+n/hmHJ/x4qT/HTTPoVeMCcuBKWrQXR1+/pYau3Fwe0tWIyG+LWzkRr/
# ZNPPupcA2Yci3qn8HR9RwvQopqSNJwn2Ri6am8AQyfVVy/BBw0t6jpoRPjwKvuUj
# fCzpae6duOxQtQ1XDN9PA2yl9sDko/+AXV/SOe8ea8QoQcv3s3ErkG+Lp6hnvw6O
# MPian4ggNkRtgtB7ro1OiopOUXJn9Y5EO3JUAXNcuM9m+5My1VEuvGytgAH3uxms
# lTnW3YbrfazaySCSSnWkhaOZ33hgbuUQfH7n2NFEAUc/cFzfmCQUikWisnJYywID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFLE40qoXTuMHX3AfZUu1n8nx2h93MB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQAHnfc2yUyoHZbvvyVKFuXh5HxxHIvIaR9JWpIf
# ITJlc/Ki03juR+vckzq3tp5fFH5LL7eIFXRIuoewMsvWeFrWufrrW4HhmhCwkqAr
# fA1C0xk+HaYs2O48YSxMX9lgS1kTTIb3YsfoFdFpKurPf2nc2Yd4wLg+Fgwmkxke
# yE3MUKVna8SZeVpEjnS5ucFck4srPwK2ORAf70I23GGyPhqgIKZphNXhSscTAQsy
# IqB5GwDMdRV5LK37NfU4YmxvCYh3TFYE/Gh01Q6yJvf9HxiEZpwW+oUk0gruHobg
# 3sgIR5rfgUo8l30vUnaDYMcPAClaFMC/QbHZSaUhWXZG1OOcMp0g9vYQNLDEqFX2
# jlquvzVSSwtHtm1KTldCjRED+kdCybcPxbPalwJigXc1BsI9CitnTf0ljwb9NkZ/
# JVI8/D62rXXzhz4F3u0iVGzwncGaxRxHG/Xv4nTrpkOeepoYbNBbMWS2G1qP3Xj7
# pVf0+4qRyAqJ0stjQjoVOJImVPWRjz5PR3Dn6adQVMBJDM6gDrj1rZTFVgCtTijq
# GZSGzvXpGkF3vYsyE6ZDma/kGdiUe5saeI6lH66PiWWXgqxt7sy2Ezv0yIjSVv+e
# MOT2QMUiZ6WCc7gVtAmXpfeIus+NmgFvM+Ic1X58e4I9EL4ZSAidSpWW0GZTLNC0
# 2mryLjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNPMIIC
# NwIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOjg2MDMtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBTb+bK
# OPAjCBflhzw5EXBuSWxeDqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3JnjAiGA8yMDI2MTExMDE2NDkzNFoY
# DzIwMjYxMTExMTY0OTM0WjB2MDwGCisGAQQBhFkKBAExLjAsMAoCBQDuncmeAgEA
# MAkCAQACAUMCAf8wBwIBAAICEP0wCgIFAO6fGx4CAQAwNgYKKwYBBAGEWQoEAjEo
# MCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG
# 9w0BAQsFAAOCAQEAMia0W0LUA0ZcHRkNXEi6BPbM4ef27gJwgapu64OVHLBOiynS
# JdJOgO1GYRIbwu1XO8adjw52bKtRmz58veiE+70WCfMx5r33Qgv57sY97sw0UHEO
# mhPxtBKSjiExDF8aAm+drYpOQBv8x4wzPyZgkGM1uD8Cn6kDwTdsgF96xC1E5YKc
# 8cK14mAmMwOo5bzxAhZ23i8NyLyXmUaVVqmJVHbamCVI+M4eZTBjRYHQ6ou/2GnM
# AHINqRlucBGC7awBfI6fbgZWY3WeD4E/q84yYSYo96ZCQ3Xdx5pbYJroNpcjVOML
# ZnDjb5Rk2BOgEa/suZCj+B/0VwT4grtJGlLwzTGCBA0wggQJAgEBMIGTMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACJYDHN8bNqndJAAEAAAIlMA0G
# CWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJ
# KoZIhvcNAQkEMSIEIOI++kD/lb/ojxLNOIj42cUgmzQh/RQSQa1Z2l/G9TeoMIH6
# BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgVg3uiHo43fL3YKYCX+UXQJjCuNZZ
# A/p0JTFqM9IcoRAwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAiWAxzfGzap3SQABAAACJTAiBCB1UTU5YdwHebaF0bSkuLG69zPO0M2g
# zScV67v4MUIXmjANBgkqhkiG9w0BAQsFAASCAgCGKVKuMe9J+QyIHtyIPRo6MAjo
# 0DluaYmT2eMJVhuTKc5RZKoVHfEhVQdLLDtlXrjbTrow75Lg643GIhViz6yNNNkT
# UwXICTcK+i6A+nhoT+3DgDwtQU2KCTkTGtAFiOgsWsIC6hHq7LSqtdGzquNW/1uD
# 5jVJQQo8U9z1UJeDybcYeVRMtUPYANKu7MOPuHv5twCWxXz/6rvodT3Zo1f4KVwE
# ic/iZ+rv1PSZtr0Qin2JJuYhPP2Jtqb+jaRKM9b2slYLu/YXWOoS+xP6FzVUixr0
# Dtqlt7Ly4mOajo4VyWtUZXxFj74jofqIg+qjHlx3rz43V1YUDipbVjAbOShSHSo1
# h08G/IcMDqKM1QJKIKwdcCGBeWqxG1pEgUxrd1lnKp/EGl9Ks6is1bJQmSatKtCK
# UJ/MgpU6H2G2fXBOR2kieCxXcQEVVP1v0PZt3bBJD73fvdWG4km8n+tg60kCUPt4
# oAthULLXLkj6U4BhJU+9b6tt79sNXTgWaNA/BYCq8Wj/OKWzB6o1JPm6aLXYXoVE
# +zh7mz6ev+2iarTpI0KVOycPUM1oQSUs3LrVo+5AN+vJVQv4u/wYtdwLioxgNcrz
# JQiklemd1lL2s1lfm5Q3YJ67hWKTUF1SQA96hAoNJf8mlRIgQzSTSbmTbWjTiLct
# swpAx3JexigajGcJ1w==
# SIG # End signature block
