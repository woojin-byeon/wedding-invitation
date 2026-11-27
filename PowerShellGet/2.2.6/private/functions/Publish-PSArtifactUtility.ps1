function Publish-PSArtifactUtility {
    [CmdletBinding(PositionalBinding = $false)]
    Param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'PublishModule')]
        [ValidateNotNullOrEmpty()]
        [PSModuleInfo]
        $PSModuleInfo,

        [Parameter(Mandatory = $true, ParameterSetName = 'PublishScript')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]
        $PSScriptInfo,

        [Parameter(Mandatory = $true, ParameterSetName = 'PublishModule')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ManifestPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetApiKey,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetPackageRoot,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Version]
        $FormatVersion,

        [Parameter(ParameterSetName = 'PublishModule')]
        [string]
        $ReleaseNotes,

        [Parameter(ParameterSetName = 'PublishModule')]
        [string[]]
        $Tags,

        [Parameter(ParameterSetName = 'PublishModule')]
        [switch]
        $SkipAutomaticTags,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Uri]
        $LicenseUri,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Uri]
        $IconUri,

        [Parameter(ParameterSetName = 'PublishModule')]
        [Uri]
        $ProjectUri,

        [Parameter(ParameterSetName = 'PublishModule')]
        [string[]]
        $Exclude
    )

    Write-Verbose "Calling Publish-PSArtifactUtility"
    Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe

    $PSArtifactType = $script:PSArtifactTypeModule
    $Name = $null
    $Description = $null
    $Version = ""
    $Author = $null
    $CompanyName = $null
    $Copyright = $null
    $requireLicenseAcceptance = "false"

    if ($PSModuleInfo) {
        $Name = $PSModuleInfo.Name
        $Description = $PSModuleInfo.Description
        $Version = $PSModuleInfo.Version
        $Author = $PSModuleInfo.Author
        $CompanyName = $PSModuleInfo.CompanyName
        $Copyright = $PSModuleInfo.Copyright

        if ($PSModuleInfo.PrivateData -and
            ($PSModuleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable") -and
            $PSModuleInfo.PrivateData["PSData"] -and
            ($PSModuleInfo.PrivateData["PSData"].GetType().ToString() -eq "System.Collections.Hashtable")
        ) {
            if ( -not $Tags -and $PSModuleInfo.PrivateData.PSData["Tags"]) {
                $Tags = $PSModuleInfo.PrivateData.PSData.Tags
            }

            if ( -not $ReleaseNotes -and $PSModuleInfo.PrivateData.PSData["ReleaseNotes"]) {
                $ReleaseNotes = $PSModuleInfo.PrivateData.PSData.ReleaseNotes
            }

            if ( -not $LicenseUri -and $PSModuleInfo.PrivateData.PSData["LicenseUri"]) {
                $LicenseUri = $PSModuleInfo.PrivateData.PSData.LicenseUri
            }

            if ( -not $IconUri -and $PSModuleInfo.PrivateData.PSData["IconUri"]) {
                $IconUri = $PSModuleInfo.PrivateData.PSData.IconUri
            }

            if ( -not $ProjectUri -and $PSModuleInfo.PrivateData.PSData["ProjectUri"]) {
                $ProjectUri = $PSModuleInfo.PrivateData.PSData.ProjectUri
            }

            if ($PSModuleInfo.PrivateData.PSData["Prerelease"]) {
                $psmoduleInfoPrereleaseString = $PSModuleInfo.PrivateData.PSData.Prerelease
                if ($psmoduleInfoPrereleaseString -and $psmoduleInfoPrereleaseString.StartsWith("-")) {
                    $Version = [string]$Version + $psmoduleInfoPrereleaseString
                }
                else {
                    $Version = [string]$Version + "-" + $psmoduleInfoPrereleaseString
                }
            }

            if ($PSModuleInfo.PrivateData.PSData["RequireLicenseAcceptance"]) {
                $requireLicenseAcceptance = $PSModuleInfo.PrivateData.PSData.requireLicenseAcceptance.ToString().ToLower()
                if ($requireLicenseAcceptance -eq "true") {
                    if ($FormatVersion -and ($FormatVersion.Major -lt $script:PSGetRequireLicenseAcceptanceFormatVersion.Major)) {
                        $message = $LocalizedData.requireLicenseAcceptanceNotSupported -f ($FormatVersion)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "requireLicenseAcceptanceNotSupported" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    if (-not $LicenseUri) {
                        $message = $LocalizedData.LicenseUriNotSpecified
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseUriNotSpecified" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    $LicenseFilePath = Join-PathUtility -Path $NugetPackageRoot -ChildPath 'License.txt' -PathType File
                    if (-not $LicenseFilePath -or -not (Test-Path -Path $LicenseFilePath -PathType Leaf)) {
                        $message = $LocalizedData.LicenseTxtNotFound
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseTxtNotFound" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    if ((Get-Content -LiteralPath $LicenseFilePath) -eq $null) {
                        $message = $LocalizedData.LicenseTxtEmpty
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseTxtEmpty" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    #RequireLicenseAcceptance is true, License uri and license.txt exist. Bump Up the FormatVersion
                    if (-not $FormatVersion) {
                        $FormatVersion = $script:CurrentPSGetFormatVersion
                    }
                }
                elseif ($requireLicenseAcceptance -ne "false") {
                    $InvalidValueForRequireLicenseAcceptance = $LocalizedData.InvalidValueBoolean -f ($requireLicenseAcceptance, "requireLicenseAcceptance")
                    Write-Warning -Message $InvalidValueForRequireLicenseAcceptance
                }
            }
        }
    }
    else {
        $PSArtifactType = $script:PSArtifactTypeScript

        $Name = $PSScriptInfo.Name
        $Description = $PSScriptInfo.Description
        $Version = $PSScriptInfo.Version
        $Author = $PSScriptInfo.Author
        $CompanyName = $PSScriptInfo.CompanyName
        $Copyright = $PSScriptInfo.Copyright

        if ($PSScriptInfo.'Tags') {
            $Tags = $PSScriptInfo.Tags
        }

        if ($PSScriptInfo.'ReleaseNotes') {
            $ReleaseNotes = $PSScriptInfo.ReleaseNotes
        }

        if ($PSScriptInfo.'LicenseUri') {
            $LicenseUri = $PSScriptInfo.LicenseUri
        }

        if ($PSScriptInfo.'IconUri') {
            $IconUri = $PSScriptInfo.IconUri
        }

        if ($PSScriptInfo.'ProjectUri') {
            $ProjectUri = $PSScriptInfo.ProjectUri
        }
    }

    $nuspecFiles = ""
    if ($Exclude) {
        $nuspecFileExcludePattern = $Exclude -Join ";"
        $nuspecFiles = @{ src = "**/*.*"; exclude = $nuspecFileExcludePattern }
    }

    # Add PSModule and PSGet format version tags
    if (-not $Tags) {
        $Tags = @()
    }

    if ($FormatVersion) {
        $Tags += "$($script:PSGetFormatVersion)_$FormatVersion"
    }

    $DependentModuleDetails = @()

    if ($PSScriptInfo) {
        $Tags += "PSScript"

        if ($PSScriptInfo.DefinedCommands -and -not $SkipAutomaticTags) {
            if ($PSScriptInfo.DefinedFunctions) {
                $Tags += "$($script:Includes)_Function"
                $Tags += $PSScriptInfo.DefinedFunctions | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Function)_$_" }
            }

            if ($PSScriptInfo.DefinedWorkflows) {
                $Tags += "$($script:Includes)_Workflow"
                $Tags += $PSScriptInfo.DefinedWorkflows | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Workflow)_$_" }
            }

            $Tags += $PSScriptInfo.DefinedCommands | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Command)_$_" }
        }

        # Populate the dependencies elements from RequiredModules and RequiredScripts
        #
        $ValidateAndGetScriptDependencies_Params = @{
            Repository          = $Repository
            DependentScriptInfo = $PSScriptInfo
            CallerPSCmdlet      = $PSCmdlet
            Verbose             = $VerbosePreference
            Debug               = $DebugPreference
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $ValidateAndGetScriptDependencies_Params.Add('Credential', $Credential)
        }
        $DependentModuleDetails += ValidateAndGet-ScriptDependencies @ValidateAndGetScriptDependencies_Params
    }
    else {
        $Tags += "PSModule"

        $ModuleManifestHashTable = Get-ManifestHashTable -Path $ManifestPath

        if (-not $SkipAutomaticTags) {
            if ($PSModuleInfo.ExportedCommands.Count) {
                if ($PSModuleInfo.ExportedCmdlets.Count) {
                    $Tags += "$($script:Includes)_Cmdlet"
                    $Tags += $PSModuleInfo.ExportedCmdlets.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Cmdlet)_$_" }

                    #if CmdletsToExport field in manifest file is "*", we suggest the user to include all those cmdlets for best practice
                    if ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey('CmdletsToExport') -and ($ModuleManifestHashTable.CmdletsToExport -eq "*")) {
                        $WarningMessage = $LocalizedData.ShouldIncludeCmdletsToExport -f ($ManifestPath)
                        Write-Warning -Message $WarningMessage
                    }
                }

                if ($PSModuleInfo.ExportedFunctions.Count) {
                    $Tags += "$($script:Includes)_Function"
                    $Tags += $PSModuleInfo.ExportedFunctions.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Function)_$_" }

                    if ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey('FunctionsToExport') -and ($ModuleManifestHashTable.FunctionsToExport -eq "*")) {
                        $WarningMessage = $LocalizedData.ShouldIncludeFunctionsToExport -f ($ManifestPath)
                        Write-Warning -Message $WarningMessage
                    }
                }

                $Tags += $PSModuleInfo.ExportedCommands.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Command)_$_" }
            }

            $dscResourceNames = Get-ExportedDscResources -PSModuleInfo $PSModuleInfo
            if ($dscResourceNames) {
                $Tags += "$($script:Includes)_DscResource"

                $Tags += $dscResourceNames | Microsoft.PowerShell.Core\ForEach-Object { "$($script:DscResource)_$_" }

                #If DscResourcesToExport is commented out or "*" is used, we will write-warning
                if ($ModuleManifestHashTable -and
                    ($ModuleManifestHashTable.ContainsKey("DscResourcesToExport") -and
                        $ModuleManifestHashTable.DscResourcesToExport -eq "*") -or
                    -not $ModuleManifestHashTable.ContainsKey("DscResourcesToExport")) {
                    $WarningMessage = $LocalizedData.ShouldIncludeDscResourcesToExport -f ($ManifestPath)
                    Write-Warning -Message $WarningMessage
                }
            }

            $RoleCapabilityNames = Get-AvailableRoleCapabilityName -PSModuleInfo $PSModuleInfo
            if ($RoleCapabilityNames) {
                $Tags += "$($script:Includes)_RoleCapability"

                $Tags += $RoleCapabilityNames | Microsoft.PowerShell.Core\ForEach-Object { "$($script:RoleCapability)_$_" }
            }
        }

        # Populate the module dependencies elements from RequiredModules and
        # NestedModules properties of the current PSModuleInfo
        $GetModuleDependencies_Params = @{
            PSModuleInfo   = $PSModuleInfo
            Repository     = $Repository
            CallerPSCmdlet = $PSCmdlet
            Verbose        = $VerbosePreference
            Debug          = $DebugPreference
        }
        if ($PSBoundParameters.ContainsKey('Credential')) {
            $GetModuleDependencies_Params.Add('Credential', $Credential)
        }
        $DependentModuleDetails = Get-ModuleDependencies @GetModuleDependencies_Params
    }

    $dependencies = @()
    ForEach ($Dependency in $DependentModuleDetails) {
        $ModuleName = $Dependency.Name
        $VersionString = ""

        # Version format in NuSpec:
        # "[2.0]" --> (== 2.0) Required Version
        # "2.0" --> (>= 2.0) Minimum Version
        #
        # When only MaximumVersion is specified in the ModuleSpecification
        # (,1.0]  = x <= 1.0
        #
        # When both Minimum and Maximum versions are specified in the ModuleSpecification
        # [1.0,2.0] = 1.0 <= x <= 2.0

        if ($Dependency.Keys -Contains "RequiredVersion") {
            $VersionString = "[$($Dependency.RequiredVersion)]"
        }
        elseif ($Dependency.Keys -Contains 'MinimumVersion' -and $Dependency.Keys -Contains 'MaximumVersion') {
            $VersionString = "[$($Dependency.MinimumVersion),$($Dependency.MaximumVersion)]"
        }
        elseif ($Dependency.Keys -Contains 'MaximumVersion') {
            $VersionString = "(,$($Dependency.MaximumVersion)]"
        }
        elseif ($Dependency.Keys -Contains 'MinimumVersion') {
            $VersionString = "$($Dependency.MinimumVersion)"
        }

        $props = @{
            id      = $ModuleName
            version = $VersionString
        }

        $dependencyObject = New-Object -TypeName PSCustomObject -Property $props
        $dependencies += $dependencyObject
    }

    $params = @{
        OutputPath               = $NugetPackageRoot
        Id                       = $Name
        Version                  = $Version
        Authors                  = $Author
        Owners                   = $CompanyName
        Description              = $Description
        ReleaseNotes             = $ReleaseNotes
        RequireLicenseAcceptance = ($requireLicenseAcceptance -eq $true)
        Copyright                = $Copyright
        Tags                     = $Tags
        LicenseUrl               = $LicenseUri
        ProjectUrl               = $ProjectUri
        IconUrl                  = $IconUri
        Dependencies             = $dependencies
    }

    if ($nuspecFiles) {
        $params.Add('Files', $nuspecFiles)
    }

    try {
        $NuspecFullName = New-NuspecFile @params
    }
    catch {
        Write-Error -Message "Failed to create nuspec file $_.Exception" -ErrorAction Stop
    }

    try {
        if ($DotnetCommandPath) {
            $NupkgFullName = New-NugetPackage -NuspecPath $NuspecFullName -NugetPackageRoot $NugetPackageRoot -UseDotnetCli -Verbose:$VerbosePreference
        }
        elseif ($NuGetExePath) {
            $NupkgFullName = New-NugetPackage -NuspecPath $NuspecFullName -NugetPackageRoot $NugetPackageRoot -NugetExePath $NuGetExePath -Verbose:$VerbosePreference
        }

        Write-Verbose -Message "Successfully created nuget package at $NupkgFullName"
    }
    catch {
        if ($PSArtifactType -eq $script:PSArtifactTypeModule) {
            $message = $LocalizedData.FailedToCreateCompressedModule -f ($_.Exception.message)
            $errorId = "FailedToCreateCompressedModule"
        }
        else {
            $message = $LocalizedData.FailedToCreateCompressedScript -f ($_.Exception.message)
            $errorId = "FailedToCreateCompressedScript"
        }

        Write-Error -Message $message -ErrorId $errorId -Category InvalidOperation -ErrorAction Stop
    }

    try {
        if ($DotnetCommandPath) {
            Publish-NugetPackage -NupkgPath $NupkgFullName -Destination $Destination -NugetApiKey $NugetApiKey -UseDotnetCli -Verbose:$VerbosePreference
        }
        elseif ($NuGetExePath) {
            Publish-NugetPackage -NupkgPath $NupkgFullName -Destination $Destination -NugetApiKey $NugetApiKey -NugetExePath $NuGetExePath -Verbose:$VerbosePreference
        }

        if ($PSArtifactType -eq "Module") {
            $message = $LocalizedData.PublishedSuccessfully -f ($Name, $Destination, $Name)
        }
        if ($PSArtifactType -eq "Script") {
            $message = $LocalizedData.PublishedScriptSuccessfully -f ($Name, $Destination, $Name)
        }

        Write-Verbose -Message $message
    }
    catch {
        if ( $NugetApiKey -eq "VSTS" -and ($_.Exception.Message -match "Cannot prompt for input in non-interactive mode.")) {
            $message = $LocalizedData.RegisterVSTSFeedAsNuGetPackageSource -f ($Destination, $script:VSTSAuthenticatedFeedsDocUrl)
        }
        else {
            $message = $_.Exception.message
        }

        if ($PSArtifactType -eq "Module") {
            $errorMessage = $LocalizedData.FailedToPublish -f ($Name, $message)
            $errorId = "FailedToPublishTheModule"
        }

        if ($PSArtifactType -eq "Script") {
            $errorMessage = $LocalizedData.FailedToPublishScript -f ($Name, $message)
            $errorId = "FailedToPublishTheScript"
        }

        Write-Error -Message $errorMessage -ErrorId $errorId -Category InvalidOperation -ErrorAction Stop
    }
}

# SIG # Begin signature block
# MIInNgYJKoZIhvcNAQcCoIInJzCCJyMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBJZmvO8jKAPtCz
# IDLljqZJ74+8+gy4rtGcYi8JqsvGD6CCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghnDMIIZvwIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIEFueEtDWfLCwdIWx4m5FQQwwrve
# moGBAyA07upO9A18MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEADd+GbIlcrMGPxT2ghVoX/NRV32bEDEgPgd7MDcz+R81PYvFEQ33ytb2krFTy
# cMXgL3Q0K8FtaoVVxusKOY40HzKLO3aP1ZpHRjDRCkgpbrE1ut8LqI8l3fujYOgF
# obPJXEIi2Ojyv7p67zLeM9EQqt6+DwpbLqLWzmyW6+m0NHuRvL+2pOsyib9Jb6g8
# tpS7ARsiFy+nvyR1BPcRyUfM6lUgwo4JOuw78ry67DBgThcKPSt4SEtydCL0Ukze
# DuUTKTms7weS8M1NRspoJulGm4GM7NUk63Wtcq8hT3lUz91kizZiq3A+nZ+T1LfW
# +inI1dxHnKC0BBDoefSWVqCnSaGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sG
# CSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCBk5gRFPMYJa0q+rZpczbsdQIUA6BPvBSthSVX6/Q+I7gIGavNuGYVIGBMy
# MDI2MTExMDIyMDUyNC4zODJaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RTAwMi0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHp
# MIIHIDCCBQigAwIBAgITMwAAAikO1WQqtJfyGgABAAACKTANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDda
# Fw0yNzA1MTcxOTQwMDdaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RTAwMi0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCeItFq4z1oCYSmUZmpYDsbJWEu++1bbc/Mz7Pa3I0ZX5EO
# N+WirB0FvnGlyFRUylzO5TJXZfU8QFPOU95P1Y1OZ8J+quA5G+AWSBOr/48scl0s
# 9RBpqgTMq/lbyqBz4CMmvVR2QevAgVp4a1hbmOm9G7YWey68N5F5rSDYV0wMlg4I
# y8YRuFgRN2eBpVXt9IvFaFmBnQLZfo22KZ3L8PWEHUhXU5dLOSZoTfqqQ/B+deW5
# 6ACMnnHjPxZu+szHhZMLUrMWTgs9J7Cn8DtelcKj9aM+0Zq7tkSDHCrwo6eCSfw3
# clktXRRrdmsccal8RCDiNFFgZsypwF2aGAF6kg41+Ql+thXpnOMUH4mPCAJZWp0z
# DWowsK/Yo5jHL1pT/AgbL3FoAy4cbhOI4Pb1eQFG+jT7skS2F/b+ZACUA1EDZ830
# K+Bu0yw+FpSGy8tpd1szk3cUYjIpzIG4z3oFNmiSJN8YdNd4SHsER5Dks5bxiKbp
# vmfrOA39jTb7EW2TT7ySWgJISfvTezuLmQsTVSzNsvapVlHhE2zBqDw409nvOtit
# CFbnhhXNfatzb2+Gf2tX2s6YBa151CC/8+emJvvegXbWNudzYt8cFRom0PZ+fJRh
# hBfdSqCqr8QeOGJ8VYlmxFXqx1SdDSkTCSgpsskGqZwh/6umA1g4L7zeGBNngQID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFCdNRaSL9AW8QvaQ21WjRAXKN4M7MB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQA9wc72lf/czDhp09T3PGAMOQhxl/x04jpE7t39
# FeqQSn2Up6DVzhgwnzCqY3NIhLtUaWrd7NxvrhZDca+J4xzvrRQNPHeRQpnJVeHs
# yTu53gTBlUB1TRI6OnZt/AVmR9oMJ/NBOqB+d+SOb8Px6zRgRwk62sFkOkB5lig/
# DMnYEeR/amW9Hdo8vXcKmaa/DbSOAHSdfZFt+iqMZfNlkEOn71/RAKTNv4Qpq/2F
# hcjMMmSkIhshBdBVB0VjmkwFfhVUf5TTuLJ9sDR4EyCvOZJ3B6g7Iw6WjQxycjwk
# fzsVMTpfusJ5SwdOHL8yGPWZOePjwa8ISXWs6kiVK/6S0/JVb1LpxpyYKREQjnU/
# 5OecKt2OXlHdwFWZrwAi98RPZa6EExcb/LGLf10tNHju1eTlohY0jzNZQ0BDgSuM
# ZgMU+8EEjtMQMIDnlPGEUON7LHXHH0KL0FA01PEWVZKrr/LUOuuDTNFzw543FPMp
# 4gkCIFlKdRuciR1IXOk+Xse6rj9tJFYgVn+44BHou2XQe5RX30ef3AQWa0mxyGDq
# JzGsV3X5+bNQeMV88iWulJPq5sgnGG9O/H1/HH4HsO9ZKGX/WrJpQmFuQrTOR49X
# jveaC0xaFmGsNg+RhbtD5qTkn+ISDvw0IJ/E/VXNdz/yWgol6r507hT8sAMupnhk
# F2uw1DCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNMMIIC
# NAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOkUwMDItMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQC3v9iS
# O22xob7ZxN5dXCEq+9Iv/6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3slzAiGA8yMDI2MTExMDE5MTg0N1oY
# DzIwMjYxMTExMTkxODQ3WjBzMDkGCisGAQQBhFkKBAExKzApMAoCBQDuneyXAgEA
# MAYCAQACAQEwBwIBAAICDw4wCgIFAO6fPhcCAQAwNgYKKwYBBAGEWQoEAjEoMCYw
# DAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0B
# AQsFAAOCAQEAOv4rwp7YnMrM9C60PiIvKXe28BHG58NXVU/1oAK7E6bvGvzJdjz3
# VeQCriRg1snsQscoSBNG5OMlbWR8WoEjBuGFfQ82MO8aTpgU59W/470pljFUQj4Y
# vjrKViiavD+3TL4niw+hoeSszQIMfDtJKZ33odiwiSfMeE4g1rgl9bbEKjjmm4DN
# FEsnblccypO2NBK+OH/qswCGYye8KtEWMDvbUx4J8XdSNLHXqGhTV78olnkIPYIS
# Pq0jdSyFA3UzEDDdAGb0EIdZhi6Wz41jEGiPK30lzctzoD5U1NnOcayjtfmNorPX
# f5r+O3gw/9tI5RRI2CtQ/kMISu8jcZKZRzGCBA0wggQJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACKQ7VZCq0l/IaAAEAAAIpMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIFTmLH02+7kWd48pUdHiWrc+nmmvczgXqTb/I/47T6AVMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgt8o98SK28P+VK8S6bGo+SR44S2CSYoUR
# Uy56X2g6upIwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAikO1WQqtJfyGgABAAACKTAiBCCwqCrA5s+fLdNvfCk5axTnVMPTcQDQilJk
# UehImTiMzjANBgkqhkiG9w0BAQsFAASCAgAfoXkr/IOCkOy/n4no6jeUy2u3m+A7
# iQvRyMD6M+skbb5H3LuaibHBtnUMkcaeTIwtoaqt5lM7Y7Ns6g0Q3KKNela343rS
# X7T+dACYHciXKphw+Q7T0VcVgT1grw3EmauZcLKT1kWiDGYN9IFYul6bGvdr+UzY
# 3vsJz8iDqUHE+gUyrKLMJpR0dRm+5xY+RwoCtflkCF7NbWUu089gqfxGb4o9ELpi
# dRvZEANV6UZCjB6/65TXpXOWrNPDuMu/NU3eiHIYIB4yj0+BOJu1IuvJIYiboFR9
# qfXyHyAFH5285aicgAwL2LOinFrOjLcXx8bzMbDNj+FzRMkMoCws7IdI7n8oKC44
# K5fDx365JEaTrA5V+t6YKTwqas0dcmeyJuhMeHrf4QvZcaTTyuDQwV40UYh6l56Z
# C4rCU/ZS2k7M0wJKXZvT6x/40WF2PuWn2w3rUwk4ZvuJNCbjQlbDjBFTnuOMrOic
# L752i/wW6eYL2gXtyWpbq8gFvShr2A8/KZkvUkziB0r/cMPqLmoXVBm9CbYDnu3N
# CsFL6AlP2WLjbdcTmnw3uTnPvdnqkODtA2Gg1b1+NBVtbA37ObHSkeGHcyGto2hh
# Fc2PEiTIBL7H8x3RZIZHmJ0lSspCMgTtu5ChDGxH/PAXHDtT+QiQQMwtjVf4/gdU
# JAy5QsM0gWKerQ==
# SIG # End signature block
