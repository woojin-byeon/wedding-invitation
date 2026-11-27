function Install-Script {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkId=619784',
        SupportsShouldProcess = $true)]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'InputObject')]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $MaximumVersion,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNull()]
        [string]
        $RequiredVersion,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Repository,

        [Parameter()]
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]
        $Scope,

        [Parameter()]
        [Switch]
        $NoPathUpdate,

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
        [switch]
        $Force,

        [Parameter(ParameterSetName = 'NameParameterSet')]
        [switch]
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

        if ($Scope -eq "AllUsers" -and -not (Test-RunningAsElevated)) {
            # Throw an error when Install-Script is used as a non-admin user and '-Scope AllUsers'
            $message = $LocalizedData.InstallScriptAdminPrivilegeRequiredForAllUsersScope -f @($script:ProgramFilesScriptsPath, $script:MyDocumentsScriptsPath)

            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InstallScriptAdminPrivilegeRequiredForAllUsersScope" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument
        }

        # If no scope is specified, default installation will be to AllUsers only
        # If running admin on Windows with PowerShell less than v6.
        if (-not $Scope) {
            $Scope = "CurrentUser"
            if (-not $script:IsCoreCLR -and (Test-RunningAsElevated)) {
                $Scope = "AllUsers"
            }
        }

        # Check and add the scope path to PATH environment variable
        if ($Scope -eq 'AllUsers') {
            $scopePath = $script:ProgramFilesScriptsPath
        }
        else {
            $scopePath = $script:MyDocumentsScriptsPath
        }

        ValidateAndSet-PATHVariableIfUserAccepts -Scope $Scope `
            -ScopePath $scopePath `
            -NoPathUpdate:$NoPathUpdate `
            -Force:$Force

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -Proxy $Proxy -ProxyCredential $ProxyCredential

        # Script names already tried in the current pipeline for InputObject parameterset
        $scriptNamesInPipeline = @()

        $YesToAll = $false
        $NoToAll = $false
        $SourceSGrantedTrust = @()
        $SourcesDeniedTrust = @()
    }

    Process {
        $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
        $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedScriptPackage
        $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage

        $PSBoundParameters["Provider"] = $script:PSModuleProviderName
        $PSBoundParameters["MessageResolver"] = $script:PackageManagementInstallScriptMessageResolverScriptBlock
        $PSBoundParameters[$script:PSArtifactType] = $script:PSArtifactTypeScript
        $PSBoundParameters['Scope'] = $Scope
        if ($AllowPrerelease) {
            $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
        }
        $null = $PSBoundParameters.Remove("AllowPrerelease")
        $null = $PSBoundParameters.Remove("PassThru")

        if ($PSCmdlet.ParameterSetName -eq "NameParameterSet") {
            $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                -Name $Name `
                -TestWildcardsInName `
                -MinimumVersion $MinimumVersion `
                -MaximumVersion $MaximumVersion `
                -RequiredVersion $RequiredVersion `
                -AllowPrerelease:$AllowPrerelease

            if (-not $ValidationResult) {
                # Validate-VersionParameters throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }

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

            if (-not $Force) {
                foreach ($scriptName in $Name) {
                    # Throw an error if there is a command with the same name and -force is not specified.
                    $cmd = Microsoft.PowerShell.Core\Get-Command -Name $scriptName `
                        -ErrorAction Ignore `
                        -WarningAction SilentlyContinue
                    if ($cmd) {
                        # Check if this script was already installed, may be with -Force
                        $InstalledScriptInfo = Test-ScriptInstalled -Name $scriptName `
                            -ErrorAction SilentlyContinue `
                            -WarningAction SilentlyContinue
                        if (-not $InstalledScriptInfo) {
                            $message = $LocalizedData.CommandAlreadyAvailable -f ($scriptName)
                            Write-Error -Message $message -ErrorId CommandAlreadyAvailableWitScriptName -Category InvalidOperation

                            # return if only single name is specified
                            if ($scriptName -eq $Name) {
                                return
                            }
                        }
                    }
                }
            }

            $installedPackages = PackageManagement\Install-Package @PSBoundParameters

            if ($PassThru) {
                $installedPackages | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "InputObject") {
            $null = $PSBoundParameters.Remove("InputObject")

            foreach ($inputValue in $InputObject) {

                if (($inputValue.PSTypeNames -notcontains "Microsoft.PowerShell.Commands.PSRepositoryItemInfo") -and
                    ($inputValue.PSTypeNames -notcontains "Deserialized.Microsoft.PowerShell.Commands.PSRepositoryItemInfo")) {
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $LocalizedData.InvalidInputObjectValue `
                        -ErrorId "InvalidInputObjectValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $inputValue
                }

                $psRepositoryItemInfo = $inputValue

                # Skip the script name if it is already tried in the current pipeline
                if ($scriptNamesInPipeline -contains $psRepositoryItemInfo.Name) {
                    continue
                }

                $scriptNamesInPipeline += $psRepositoryItemInfo.Name

                if ($psRepositoryItemInfo.PowerShellGetFormatVersion -and
                    ($script:SupportedPSGetFormatVersionMajors -notcontains $psRepositoryItemInfo.PowerShellGetFormatVersion.Major)) {
                    $message = $LocalizedData.NotSupportedPowerShellGetFormatVersionScripts -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.PowerShellGetFormatVersion, $psRepositoryItemInfo.Name)
                    Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                    continue
                }

                $PSBoundParameters["Name"] = $psRepositoryItemInfo.Name
                $PSBoundParameters["RequiredVersion"] = $psRepositoryItemInfo.Version
                if (($psRepositoryItemInfo.AdditionalMetadata) -and
                    (Get-Member -InputObject $psRepositoryItemInfo.AdditionalMetadata -Name "IsPrerelease") -and
                    ($psRepositoryItemInfo.AdditionalMetadata.IsPrerelease -eq "true")) {
                    $PSBoundParameters[$script:AllowPrereleaseVersions] = $true
                }
                elseif ($PSBoundParameters.ContainsKey($script:AllowPrereleaseVersions)) {
                    $null = $PSBoundParameters.Remove($script:AllowPrereleaseVersions)
                }
                $PSBoundParameters['Source'] = $psRepositoryItemInfo.Repository
                $PSBoundParameters["PackageManagementProvider"] = (Get-ProviderName -PSCustomObject $psRepositoryItemInfo)

                $InstalledScriptInfo = Test-ScriptInstalled -Name $psRepositoryItemInfo.Name
                if (-not $Force -and $InstalledScriptInfo) {
                    $message = $LocalizedData.ScriptAlreadyInstalledVerbose -f ($InstalledScriptInfo.Version, $InstalledScriptInfo.Name, $InstalledScriptInfo.ScriptBase)
                    Write-Verbose -Message $message
                }
                else {
                    # Throw an error if there is a command with the same name and -force is not specified.
                    if (-not $Force) {
                        $cmd = Microsoft.PowerShell.Core\Get-Command -Name $psRepositoryItemInfo.Name `
                            -ErrorAction Ignore `
                            -WarningAction SilentlyContinue
                        if ($cmd) {
                            $message = $LocalizedData.CommandAlreadyAvailable -f ($psRepositoryItemInfo.Name)
                            Write-Error -Message $message -ErrorId CommandAlreadyAvailableWitScriptName -Category InvalidOperation

                            continue
                        }
                    }

                    $source = $psRepositoryItemInfo.Repository
                    $installationPolicy = (Get-PSRepository -Name $source).InstallationPolicy
                    $ShouldProcessMessage = $PackageTarget -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.Version)

                    if ($psCmdlet.ShouldProcess($ShouldProcessMessage)) {
                        if ($installationPolicy.Equals("Untrusted", [StringComparison]::OrdinalIgnoreCase)) {
                            if (-not($YesToAll -or $NoToAll -or $SourceSGrantedTrust.Contains($source) -or $sourcesDeniedTrust.Contains($source) -or $Force)) {
                                $message = $QueryInstallUntrustedPackage -f ($psRepositoryItemInfo.Name, $psRepositoryItemInfo.RepositorySourceLocation)

                                if ($PSVersionTable.PSVersion -ge '5.0.0') {
                                    $sourceTrusted = $psCmdlet.ShouldContinue("$message", "$RepositoryIsNotTrusted", $true, [ref]$YesToAll, [ref]$NoToAll)
                                }
                                else {
                                    $sourceTrusted = $psCmdlet.ShouldContinue("$message", "$RepositoryIsNotTrusted", [ref]$YesToAll, [ref]$NoToAll)
                                }

                                if ($sourceTrusted) {
                                    $SourcesGrantedTrust += $source
                                }
                                else {
                                    $SourcesDeniedTrust += $source
                                }
                            }
                        }
                    }
                    if ($installationPolicy.Equals("trusted", [StringComparison]::OrdinalIgnoreCase) -or $SourcesGrantedTrust.Contains($source) -or $YesToAll -or $Force) {
                        $PSBoundParameters["Force"] = $true
                        $installedPackages = PackageManagement\Install-Package @PSBoundParameters

                        if ($PassThru) {
                            $installedPackages | Microsoft.PowerShell.Core\ForEach-Object { New-PSGetItemInfo -SoftwareIdentity $_ -Type $script:PSArtifactTypeScript }
                        }
                    }
                }
            }
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB1mUBtgWFT5un1
# UzICbFI4tBj6oydEgeLHeuCmOdMZYKCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIH5iHxUVKWH42eTaWS6QOit2Rfb/
# STVH+LY6c+sGWZ/bMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAIOYBteJlEO8rwvLm70+YvE4G/bbkkHuXNhFPnAgTzDnUutZuucBE1pl2XzqY
# JCbUDfjBLLjQhxvYUtRzDiV6YRPOPXY8B2feWm5QgJq3+eYS1TAWNq3shH/5LFuC
# noSSYeb+4RKq6dTPtlNwAYCC/kDvq3DIZGEOetQ8dmRNY/Yl/qh2FbHkCLI7x3dD
# OthFXOK88xqp9FAOMVM8JXOMbBY85FTAoWh+OhE1Q4RHHbetOY2q88NFpVXS9dZ7
# BXTv4SuMaj5ej5F2CWeQYnfkrIKovQbPJBv42E9CxVUH1ogGeB98snWtAbtLiSUi
# lTIaHhAI0+RJT/+mQdbJsMc68KGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34G
# CSqGSIb3DQEHAqCCF28wghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCCa8FuZ9joaYyZMKwvhbuWEywlmZm1FMyUEoyOAC6xjrQIGavNt1MsbGBMy
# MDI2MTExMDIyMDU1MC42NTFaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTkzNS0wM0Uw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHs
# MIIHIDCCBQigAwIBAgITMwAAAifVwIPDsS5XLQABAAACJzANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDRa
# Fw0yNzA1MTcxOTQwMDRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTkzNS0wM0UwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDixWy1fDOSL4qj3A1pady+elIDLwnF3UuLzJIOWwGHcEgr
# xxwtnyviUIDmmxylTUl1u+2rBPp2zT4BwwQhvGaJpExqvPLlDFlbfmSflKI86eFq
# ofiZ7j8NTRO4l7wGg9Njm+muNauTcFW2qdfIjKE950Okrm9MnMOGYy+fibNYdxTP
# RPq1T4MLZK3s3vdMyMEOldcOQkSKpxD6/1Gk6gOmCu2KgI8f0ex6vYxnKDl9W0OL
# SEa/6y82oIbsm+1QBifOQ47xWKTG1CmvtGr85LzA75/MAcUmRw5/of/qET0UFV1W
# ulMcJrI6DASAsNCNB+6WLrotuBZAj+VMlqbn5RMZ6Q4IY7JwaAiIXh7VjxrnwUOY
# ZG8WEGhfrA98di+7LEn9AqvvEOyG+UQcjVhCCbMGXigJXSApeyeWupCsD0jgQMNC
# xfB5BLBDWxgdY3dJBEPgxfkgTDQLBggtVv2d5CYxHKgIItB4bI5eSb5jkIG2Wotn
# FetT0legpw/Eozwf39ao6tENY21eVWIzRw/GsmvwjYQF6vVrxOD0pGVsfqGF8s3V
# PeY7hI2TxHFMqNA0IB/a2NLY7JTxYAKAP/11EJZt7xbqDLMgD1YDdGEzGpQijm3n
# APCL2CebP/jmu90abJ2W425yglGHTI/nCBrwSpfRCgwzrfFelJaCKM6+35aFfwID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFNLW58N4MGSG6ud7jWqgT92orfReMB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQAqncud4PSC1teb2H6nRuy7sDiKK13FXJirVB4T
# fwjdo2Mb+QL4j7wZ/k4G9P0CANHZFrDQcK0VFDTysrYu8Z0Aha14acDZPsyIoPvA
# GRRhaHEuf7NckRjkfa/ylo1KyII8jbL9N9sJAqBPL8V4FNBjljv+1GHDOw127rZz
# 5ZSTPoAPb2SA0v5yDgcpUMfxglPyp6cnPPoQpTtD9OGx8Dwm2P+o1TPxBIy6I0T9
# RauulogVCvKwflfeLTcKAvnSG1rCjerSXmU1DNXOsAD/bsrSjgbX5mAbD7XTRMF/
# vawAWESFcn/BjjizxeWZb00aYSlkJA2rVtFlMM481aVWXdAbXPP5RzUiWTlgyHf/
# G7lCxHYWGIZuB13T3aI6Y8mEgn/ou40aiFJo8r0+i0P5GdNneWtxiR0CMKUfko+5
# s/73cwe1Wfp8BKXa270cicVQasFf5sRV7pFm+V7fNRXwCu7anTOmga76zO7/2t+z
# OlibvphT+Q6Zd+B2qYsSn4xBaY+YzHpnycLW5cvJyhPxBCcb1oRYfhRzCADb2utI
# 2EtGCjc2P2ii4LyR4QMb/n8cOweL9IqVTKKzzVk+zZJxV3vrp4LyuQXw0O30la6B
# cHdNAAAB9UC83zs3G9d+AlIfZLM97tMUNKWjbBpIirFx6LTDFXVtZQd7hqzLYByj
# bjH0ujCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# A1UECxMeblNoaWVsZCBUU1MgRVNOOkE5MzUtMDNFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQAjHzqt
# hPwO0GDckDMA6x54lIiMKqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3sUTAiGA8yMDI2MTExMDE5MTczN1oY
# DzIwMjYxMTExMTkxNzM3WjB2MDwGCisGAQQBhFkKBAExLjAsMAoCBQDunexRAgEA
# MAkCAQACARcCAf8wBwIBAAICEvAwCgIFAO6fPdECAQAwNgYKKwYBBAGEWQoEAjEo
# MCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG
# 9w0BAQsFAAOCAQEAZraAlqIgyJ4yWSVy1TVLk9GceYs0g1AyK7SNjAQmsI9CCZH9
# JyRw39GmvI4CRaJMJp0nSMSFTKwFaokL9xYWhmFUJ47AMi+527yFhhiuSIehGZLH
# RcKnlkSlLpOO/gKKBouv0XmwPsq+7drUqtNaROcEAhl7HaVHUD+wE0Lqy9BOYG+Z
# npKIDrrqf3DLybjPXk7X6zT9ACQazGkEWez17xYLKtyPe+i6ob5012vg/JOLzbjT
# e8Arns51aG6ZZ8UrICaeFvsJ/Kfwkw2ONM11RUvJ5zv5Mqw9ALJOqjpBttaNF8Y/
# GvwSqcqA16bDMQs36O81m7DHD03n+QxKx9gxATGCBA0wggQJAgEBMIGTMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACJ9XAg8OxLlctAAEAAAInMA0G
# CWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJ
# KoZIhvcNAQkEMSIEIJqMn++4RUe8sMMJGOrjcRyaZ8XPqQTR6fq69mZ1h9XXMIH6
# BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQg5ecBGjWhUhw4skoOqUTRp2r+Nn1N
# d2WddZFxcZOEEXIwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAifVwIPDsS5XLQABAAACJzAiBCBXWLIwmxP1mWrYgCOt0tUsypAno7r8
# Bk6s4EiunbuJ1DANBgkqhkiG9w0BAQsFAASCAgAgDMyduKGUz+0Gmo3sUfIP2xCn
# NquZyg40ZNULPPvYHRbk5SuDguA4TYxplwDfQH55J0APFSnsjH4lBWY3Grm84hV3
# iwLyiDKn7jPLu8c0KsFK6fM/G/JubPi1TkGiUktTXPZgr+Ic1E/NWrAFChtXK5of
# OWFFY2sXOqOFwFuZt0AYeIFU2HOwopGBdWcTnIldPmcY+RwpJ/3ByB618gy/wnbs
# Gqs86XCQGtRHcNmrV6F2FKpFp9/+ERBV/gDvhylX8vBxA0wL0ftxz9EckSYnMPEQ
# /z7vnaJ3HaE89Rumu/N4OvKv5aF+HtRiCxlehkhsf9Ulegas4tIBppCdbK6XEL+2
# W2FiFP5/Nm51gvOnXUvi2UFtmC28vkbUivqhL1r8splzDQ7QVhsImWWO9Z1ny1sR
# lZxD/o3Kq3xi2G0nzVZQ9c11/5FokxB4DKVsFoEYVZGPJ22yVvbibOeGQ0spGwv6
# RlCXpn4+N+/BTjENv08BkVUCN79ieH8yVoRXDy6i5oFoBu+92Dg0Vwdn6dx1533t
# m3dL6x5hR8noJRGzEjOBbMKL53KwbtLG6XZmuQ3LeyGUyuYGht+2eMdi2u3QIyXH
# B2Ka7yKj5fyC2/SjiXJ7dxhFwTwLiOWA2bpvDfbnQO5ulWvT7cpOD6Piaq6akSSO
# yUDrg7ha1u7iPqtWOg==
# SIG # End signature block
