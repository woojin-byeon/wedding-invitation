function Publish-Module {
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess = $true,
        PositionalBinding = $false,
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398575',
        DefaultParameterSetName = "ModuleNameParameterSet")]
    Param
    (
        [Parameter(Mandatory = $true,
            ParameterSetName = "ModuleNameParameterSet",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true,
            ParameterSetName = "ModulePathParameterSet",
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(ParameterSetName = "ModuleNameParameterSet")]
        [ValidateNotNullOrEmpty()]
        [string]
        $RequiredVersion,

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
        [ValidateSet("2.0")]
        [Version]
        $FormatVersion,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter(ParameterSetName = "ModuleNameParameterSet")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Exclude,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName = "ModuleNameParameterSet")]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [switch]
        $SkipAutomaticTags
    )

    Begin {
        # Change security protocol to TLS 1.2
        $script:securityProtocol = [Net.ServicePointManager]::SecurityProtocol
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        if ($LicenseUri -and -not (Test-WebUri -uri $LicenseUri)) {
            $message = $LocalizedData.InvalidWebUri -f ($LicenseUri, "LicenseUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InvalidWebUri" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $LicenseUri
        }

        if ($IconUri -and -not (Test-WebUri -uri $IconUri)) {
            $message = $LocalizedData.InvalidWebUri -f ($IconUri, "IconUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InvalidWebUri" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $IconUri
        }

        if ($ProjectUri -and -not (Test-WebUri -uri $ProjectUri)) {
            $message = $LocalizedData.InvalidWebUri -f ($ProjectUri, "ProjectUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "InvalidWebUri" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $ProjectUri
        }

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force:$Force
    }

    Process {
        if ($Repository -eq $Script:PSGalleryModuleSource) {
            $moduleSource = Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if (-not $moduleSource) {
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
            $moduleSource = Get-PSRepository -Name $Repository -ErrorVariable ev
            if ($ev) { return }
        }

        $DestinationLocation = $moduleSource.PublishLocation

        if (-not $DestinationLocation -or
            (-not (Microsoft.PowerShell.Management\Test-Path $DestinationLocation) -and
                -not (Test-WebUri -uri $DestinationLocation))) {
            $message = $LocalizedData.PSGalleryPublishLocationIsMissing -f ($Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PSGalleryPublishLocationIsMissing" `
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

        $providerName = Get-ProviderName -PSCustomObject $moduleSource
        if ($providerName -ne $script:NuGetProviderName) {
            $message = $LocalizedData.PublishModuleSupportsOnlyNuGetBasedPublishLocations -f ($moduleSource.PublishLocation, $Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $message `
                -ErrorId "PublishModuleSupportsOnlyNuGetBasedPublishLocations" `
                -CallerPSCmdlet $PSCmdlet `
                -ErrorCategory InvalidArgument `
                -ExceptionObject $Repository
        }

        $moduleName = $null

        if ($Name) {
            if ($RequiredVersion) {
                $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                    -Name $Name `
                    -RequiredVersion $RequiredVersion `
                    -AllowPrerelease:$AllowPrerelease
                if (-not $ValidationResult) {
                    # Validate-VersionParameters throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }

                $reqResult = ValidateAndGet-VersionPrereleaseStrings -Version $RequiredVersion -CallerPSCmdlet $PSCmdlet
                if (-not $reqResult) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $reqVersion = $reqResult["Version"]
                $reqPrerelease = $reqResult["Prerelease"]
            }
            else {
                $reqVersion = $null
                $reqPrerelease = $null
            }

            # Find the module to be published locally, search by name and RequiredVersion
            $module = Microsoft.PowerShell.Core\Get-Module -ListAvailable -Name $Name -Verbose:$false |
            Microsoft.PowerShell.Core\Where-Object {
                $modInfoPrerelease = $null
                if ($_.PrivateData -and
                    $_.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                    $_.PrivateData["PSData"] -and
                    $_.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                    $_.PrivateData.PSData["Prerelease"]) {
                    $modInfoPrerelease = $_.PrivateData.PSData.Prerelease
                }
                (-not $RequiredVersion) -or ( ($reqVersion -eq $_.Version) -and ($reqPrerelease -match $modInfoPrerelease) )
            }

            if (-not $module) {
                if ($RequiredVersion) {
                    $message = $LocalizedData.ModuleWithRequiredVersionNotAvailableLocally -f ($Name, $RequiredVersion)
                }
                else {
                    $message = $LocalizedData.ModuleNotAvailableLocally -f ($Name)
                }

                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "ModuleNotAvailableLocallyToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name

            }
            elseif ($module.GetType().ToString() -ne "System.Management.Automation.PSModuleInfo") {
                $message = $LocalizedData.AmbiguousModuleName -f ($Name)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "AmbiguousModuleNameToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name
            }

            $moduleName = $module.Name
            $Path = $module.ModuleBase
        }
        else {
            $resolvedPath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if (-not $resolvedPath -or
                -not (Microsoft.PowerShell.Management\Test-Path -Path $resolvedPath -PathType Container)) {
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage ($LocalizedData.PathIsNotADirectory -f ($Path)) `
                    -ErrorId "PathIsNotADirectory" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Path
                return
            }

            $moduleName = Microsoft.PowerShell.Management\Split-Path -Path $resolvedPath -Leaf
            $modulePathWithVersion = $false

            # if the Leaf of the $resolvedPath is a version, use its parent folder name as the module name
            [Version]$ModuleVersion = $null
            if ([System.Version]::TryParse($moduleName, ([ref]$ModuleVersion))) {
                $moduleName = Microsoft.PowerShell.Management\Split-Path -Path (Microsoft.PowerShell.Management\Split-Path $resolvedPath -Parent) -Leaf
                $modulePathWithVersion = $true
            }

            $manifestPath = Join-PathUtility -Path $resolvedPath -ChildPath "$moduleName.psd1" -PathType File
            $module = $null

            if (Microsoft.PowerShell.Management\Test-Path -Path $manifestPath -PathType Leaf) {
                $ev = $null
                $module = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath `
                    -ErrorVariable ev `
                    -Verbose:$VerbosePreference
                if ($ev) {
                    # Above Test-ModuleManifest cmdlet should write an errors to the Errors stream and Console.
                    return
                }
            }
            elseif (-not $modulePathWithVersion -and ($PSVersionTable.PSVersion -ge '5.0.0')) {
                $module = Microsoft.PowerShell.Core\Get-Module -Name $resolvedPath -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false
            }

            if (-not $module) {
                $message = $LocalizedData.InvalidModulePathToPublish -f ($Path)

                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'InvalidModulePathToPublish' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Path
            }
            elseif ($module.GetType().ToString() -ne "System.Management.Automation.PSModuleInfo") {
                $message = $LocalizedData.AmbiguousModulePath -f ($Path)
                ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId 'AmbiguousModulePathToPublish' `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Path
            }

            if ($module -and (-not $module.Path.EndsWith('.psd1', [System.StringComparison]::OrdinalIgnoreCase))) {
                $message = $LocalizedData.InvalidModuleToPublish -f ($module.Name)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidModuleToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $module.Name
            }

            $moduleName = $module.Name
            $Path = $module.ModuleBase
        }

        $message = $LocalizedData.PublishModuleLocation -f ($moduleName, $Path)
        Write-Verbose -Message $message

        #If users are providing tags using -Tags while running PS 5.0, will show warning messages
        if ($Tags) {
            $message = $LocalizedData.TagsShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($ReleaseNotes) {
            $message = $LocalizedData.ReleaseNotesShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($LicenseUri) {
            $message = $LocalizedData.LicenseUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($IconUri) {
            $message = $LocalizedData.IconUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if ($ProjectUri) {
            $message = $LocalizedData.ProjectUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }


        # Copy the source module to temp location to publish
        $tempModulePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath `
            -ChildPath "$(Microsoft.PowerShell.Utility\Get-Random)\$moduleName"


        if ($FormatVersion -eq "1.0") {
            $tempModulePathForFormatVersion = Microsoft.PowerShell.Management\Join-Path $tempModulePath "Content\Deployment\$script:ModuleReferences\$moduleName"
        }
        else {
            $tempModulePathForFormatVersion = $tempModulePath
        }

        $null = Microsoft.PowerShell.Management\New-Item -Path $tempModulePathForFormatVersion -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false

        # Copy-Item -Recurse -Force includes hidden items like .git directories, which we don't want
        # This finds all the items without force (leaving out hidden files and dirs) then copies them
        Microsoft.PowerShell.Management\Get-ChildItem $Path -recurse |
        Microsoft.PowerShell.Management\Copy-Item -Force -Confirm:$false -WhatIf:$false -Destination {
            if ($_.PSIsContainer) {
                Join-Path $tempModulePathForFormatVersion $_.Parent.FullName.substring($path.length)
            }
            else {
                join-path $tempModulePathForFormatVersion $_.FullName.Substring($path.Length)
            }
        }

        try {
            $manifestPath = Join-PathUtility -Path $tempModulePathForFormatVersion -ChildPath "$moduleName.psd1" -PathType File

            if (-not (Microsoft.PowerShell.Management\Test-Path $manifestPath)) {
                $message = $LocalizedData.InvalidModuleToPublish -f ($moduleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidModuleToPublish" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $moduleName
            }

            $ev = $null
            $moduleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath `
                -ErrorVariable ev `
                -Verbose:$VerbosePreference
            if ($ev) {
                # Above Test-ModuleManifest cmdlet should write an errors to the Errors stream and Console.
                return
            }

            if (-not $moduleInfo -or
                -not $moduleInfo.Author -or
                -not $moduleInfo.Description) {
                $message = $LocalizedData.MissingRequiredManifestKeys -f ($moduleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "MissingRequiredModuleManifestKeys" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $moduleName
            }

            # Validate Prerelease string
            $moduleInfoPrerelease = $null
            if ($moduleInfo.PrivateData -and
                $moduleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                $moduleInfo.PrivateData["PSData"] -and
                $moduleInfo.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                $moduleInfo.PrivateData.PSData["Prerelease"]) {
                $moduleInfoPrerelease = $moduleInfo.PrivateData.PSData.Prerelease
            }

            $result = ValidateAndGet-VersionPrereleaseStrings -Version $moduleInfo.Version -Prerelease $moduleInfoPrerelease -CallerPSCmdlet $PSCmdlet
            if (-not $result) {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $moduleInfoVersion = $result["Version"]
            $moduleInfoPrerelease = $result["Prerelease"]
            $moduleInfoFullVersion = $result["FullVersion"]

            $FindParameters = @{
                Name            = $moduleName
                Repository      = $Repository
                Tag             = 'PSScript'
                AllowPrerelease = $true
                Verbose         = $VerbosePreference
                ErrorAction     = 'SilentlyContinue'
                WarningAction   = 'SilentlyContinue'
                Debug           = $DebugPreference
            }

            if ($Credential) {
                $FindParameters[$script:Credential] = $Credential
            }

            # Check if the specified module name is already used for a script on the specified repository
            # Use Find-Script to check if that name is already used as scriptname
            $scriptPSGetItemInfo = Find-Script @FindParameters |
            Microsoft.PowerShell.Core\Where-Object { $_.Name -eq $moduleName } |
            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore
            if ($scriptPSGetItemInfo) {
                $message = $LocalizedData.SpecifiedNameIsAlearyUsed -f ($moduleName, $Repository, 'Find-Script')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedNameIsAlearyUsed" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $moduleName
            }

            $null = $FindParameters.Remove('Tag')
            $currentPSGetItemInfo = Find-Module @FindParameters |
            Microsoft.PowerShell.Core\Where-Object { $_.Name -eq $moduleInfo.Name } |
            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if ($currentPSGetItemInfo) {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $currentPSGetItemInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result) {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $currentPSGetItemVersion = $result["Version"]
                $currentPSGetItemPrereleaseString = $result["Prerelease"]
                $currentPSGetItemFullVersion = $result["FullVersion"]

                if ($currentPSGetItemVersion -eq $moduleInfoVersion) {
                    # Compare Prerelease strings
                    if (-not $currentPSGetItemPrereleaseString -and -not $moduleInfoPrerelease) {
                        $message = $LocalizedData.ModuleVersionIsAlreadyAvailableInTheGallery -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName 'System.InvalidOperationException' `
                            -ExceptionMessage $message `
                            -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery' `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                    }
                    elseif (-not $Force -and (-not $currentPSGetItemPrereleaseString -and $moduleInfoPrerelease)) {
                        # User is trying to publish a new Prerelease version AFTER publishing the stable version.
                        $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation
                    }

                    # elseif ($currentPSGetItemPrereleaseString -and -not $moduleInfoPrerelease) --> allow publish
                    # User is attempting to publish a stable version after publishing a Prerelease version (allowed).

                    elseif ($currentPSGetItemPrereleaseString -and $moduleInfoPrerelease) {
                        if ($currentPSGetItemPrereleaseString -eq $moduleInfoPrerelease) {
                            $message = $LocalizedData.ModuleVersionIsAlreadyAvailableInTheGallery -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName 'System.InvalidOperationException' `
                                -ExceptionMessage $message `
                                -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery' `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation
                        }

                        elseif (-not $Force -and ($currentPSGetItemPrereleaseString -gt $moduleInfoPrerelease)) {
                            $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName "System.InvalidOperationException" `
                                -ExceptionMessage $message `
                                -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                                -CallerPSCmdlet $PSCmdlet `
                                -ErrorCategory InvalidOperation
                        }

                        # elseif ($currentPSGetItemPrereleaseString -lt $moduleInfoPrerelease) --> allow publish
                    }
                }
                elseif (-not $Force -and (Compare-PrereleaseVersions -FirstItemVersion $moduleInfoVersion `
                            -FirstItemPrerelease $moduleInfoPrerelease `
                            -SecondItemVersion $currentPSGetItemVersion `
                            -SecondItemPrerelease $currentPSGetItemPrereleaseString)) {
                    $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation
                }

                # else ($currentPSGetItemVersion -lt $moduleInfoVersion) --> allow publish
            }

            $shouldProcessMessage = $LocalizedData.PublishModulewhatIfMessage -f ($moduleInfo.Version, $moduleInfo.Name)
            if ($Force -or $PSCmdlet.ShouldProcess($shouldProcessMessage, "Publish-Module")) {
                $PublishPSArtifactUtility_Params = @{
                    PSModuleInfo      = $moduleInfo
                    ManifestPath      = $manifestPath
                    NugetApiKey       = $NuGetApiKey
                    Destination       = $DestinationLocation
                    Repository        = $Repository
                    NugetPackageRoot  = $tempModulePath
                    FormatVersion     = $FormatVersion
                    ReleaseNotes      = $($ReleaseNotes -join "`r`n")
                    Tags              = $Tags
                    SkipAutomaticTags = $SkipAutomaticTags
                    LicenseUri        = $LicenseUri
                    IconUri           = $IconUri
                    ProjectUri        = $ProjectUri
                    Verbose           = $VerbosePreference
                    WarningAction     = $WarningPreference
                    ErrorAction       = $ErrorActionPreference
                    Debug             = $DebugPreference
                }
                if ($PSBoundParameters.Containskey('Credential')) {
                    $PublishPSArtifactUtility_Params.Add('Credential', $Credential)
                }
                if ($Exclude) {
                    $PublishPSArtifactUtility_Params.Add('Exclude', $Exclude)
                }
                Publish-PSArtifactUtility @PublishPSArtifactUtility_Params
            }
        }
        finally {
            Microsoft.PowerShell.Management\Remove-Item $tempModulePath -Force -Recurse -ErrorAction Ignore -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }

    End {
        # Change back to user specified security protocol
        [Net.ServicePointManager]::SecurityProtocol = $script:securityProtocol
    }
}

# SIG # Begin signature block
# MIInQwYJKoZIhvcNAQcCoIInNDCCJzACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBPWfdnZI5Qi8Ig
# EG6lM73U+4umtOBE0wtUAkrP7NmIf6CCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KoZIhvcNAQkEMSIEIJGC9zxOBRPZwmXIN/kGPuWXNonnjg+A7YTOCtsAZu1fMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEAdIyTRaM49ryLapUd
# E7y70sgPZna1WBG73RMjRYAF3OdLMuCCdaOORNNRFWRl80WACuLtAbSQjIjfWCoZ
# ESZLr14yEnpYK3LU1+6Mbsot8Kaa77sxs1CzxwtUTRxV6Z4Uqe6aIeDPaZN3W9Dw
# 2xQFJdNjvPewPKSZiTN5n0YfnBmDSJoKHPlFujl+nhMDkw41XR81DWRCFOkSUrD3
# V/dhjDYa9N+By/hZKWbv0XZxPouoGQar63KMIrt5g7bnRP4zG5dHS7C8W3TNQn/Q
# j7oM8miV0Xq9p7aEuGTYDgnvj+yNAEpyKSg9NEwRIuJm9Ew24PGDmXqe/Y17egx1
# zUk716GCF68wgherBgorBgEEAYI3AwMBMYIXmzCCF5cGCSqGSIb3DQEHAqCCF4gw
# gheEAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFF
# MIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCA52ndok+8cT/v6
# 839rl8miKLomUK3t5riB5ORpbsCt1gIGavNLkcnrGBMyMDI2MTExMDIyMDYxNy40
# MDJaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExp
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MDFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf0wggcoMIIF
# EKADAgECAhMzAAACLYG/a+LjBFoJAAEAAAItMA0GCSqGSIb3DQEBCwUAMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI2MTAxNTE4MzczMVoXDTI4MDEx
# MTE4MzczMVowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# LTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjQwMUEtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA3jhooxD1sifzdvJza5QdJ1cYpm4gAM5ZW6q/M4u4Glmm
# UEf3u4G1eYjEY/q+iS47Jur6WvlF7FiAhc1lHAwmvXbPSsO3xKqPKKY8N4/qpr3r
# 7SjtuuLbviU/7Ho24123ghZm6AcM/7+bXBGyfp5hUdP7PlS0XIY47emCBqxo+4K4
# X8R7E7lRfIaUPkDcXdXj+BmSIWcl/LzkIS9bplnC2JK0aZPdYfUjoDaK/Xa6GQ8w
# SU91bMB55CPwtzjDG+UmI/vTPsrBtTitDB2Ewy/HxvE7BaaiZhGzuy46u85uIWMK
# 9bGSWRLvfMYquxbBxDykquw02Kg0j2wuXrYKyo0rd4h4mGBANhum1giNVYVFOaAv
# 6uOOYogsexPHn+0LPvEkKwKuoN6PrEc1X23hULWCv+FdJ/DizF7BfmL91Hz2qHOm
# GHE3NgYYaIp5+41dKPu4c9J3cVZpM32mDR4LOzMp3ML6XYN8BjlNtXQiCjfLX+Z/
# NZja2c4pc2RJoL0rYZzFvyaM1EIPEK3/YQLnNjP4qF621ABOc58TJVpIUzq/smb4
# 7m5piJ2CI/hnj8OMosdfoc9nMDdPiMVGzLKCWsDSdL8u9XllVhOGVlzif1/hbFf1
# 8WueVPsDXwM4It/lpIwnN0ysOaTsWaqsM6W9UeArKVCm7tDiU1qW8Z2I0nl/I2UC
# AwEAAaOCAUkwggFFMB0GA1UdDgQWBBRfR318UuhZlY76h4i66CS5f7LmFDAfBgNV
# HSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBU
# aW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwG
# CCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRz
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIH
# gDANBgkqhkiG9w0BAQsFAAOCAgEAjsf7mzXo62pir+lwrH2PBItGMHdgAiXNCjSX
# R/OiuswgxZUQTADw1qTgcQ2lNoUKO2XhA2JFa1/dKPoTzjKlS4C5y9Mx1M8wuJC6
# QDlORIqEmiLpuGfO9fCktitVad7lzOP6x8f3NVeetRnd0tQi7YjZta2GKKqAr7SU
# nBfauf1FJuaR6tdhodQxtEj9bjRGzNX8gZr7gBDhQD1xQyR8OJuGuZGw8AtF9SOj
# +3zDNXTrv3hA0NQaqmhBwsNejh+SJBTsaz9IdaOkJN6qV8yElW3UGJLsLzX2PZlh
# xMkfo6fZ0e7C8/KC72ctxHEa2Y9IooP9uupHeQOf1F27/7/wqTm2aY00em+/VYg+
# 3KANw03+wM0bFvHRuwHHjz5N1w7cSko2FJ/Bh1GaVyqAvCwIR/JmYyV2kME8JwRS
# M6o+53k0UTyUT0phVF975CAUQDgANK0hT9k5yn5GcTNiPU7QtWUZ17/yCi0Ug8Fs
# mwJrH2mxVBkXaNy4zShFe1mBoWAG/j/YL8dofuV4h+C9qvU3cf/GAVAd+NLqYN4t
# NoeBbuvfWzQ/ar/jqm2wkR0aqWCqASfIqBlUDmjoGXfzh+Cr0t0MKK4wUYyDmScW
# EQl5ZNjH3Fk7k3vtDFJkr3U5xOWVllMsnkxVlFdJV/LNc9pRfsgVh0o3hviqOCX9
# CHlJzcYwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3
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
# bWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MDFBLTA1RTAtRDk0NzEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsO
# AwIaAxUAzrrnNulrssYZUj8+V9OruBe6tzGggYMwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO6dygowIhgPMjAyNjEx
# MTAxNjUxMjJaGA8yMDI2MTExMTE2NTEyMlowdjA8BgorBgEEAYRZCgQBMS4wLDAK
# AgUA7p3KCgIBADAJAgEAAgENAgH/MAcCAQACAhMvMAoCBQDunxuKAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMB
# hqAwDQYJKoZIhvcNAQELBQADggEBAB5VJGRgbpji5G78E+/Zq2l8drPpD4NWJqP6
# 7tQMyN4B1AMCP+o+vGtpM6QHBz4eKACcIvRgD2OwMvXYtHWuz2/XyIW50kfdLhJX
# yjrgPL1jczE55nwNuCnt4aNecdW3kowlPGZpm7q/glFAiHTCsUVsa9VQV/h5mLNj
# AhCtVr8p43Jdch+8UWndEw1NaDhK2PsCV/R+F7dtQYcIgrpbUMpK+olr3KiUO3fy
# Gk0JcS5DPQcvzrZ959QXHV16WrlpenFCvR82b0r6Jmzas8/e8X5sTsFEC26t+RZf
# RtugvfkKfSsD5QTPEBG6mTQyPbUOORwhrGfxppI2xNtciN0r7aYxggQNMIIECQIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAi2Bv2vi4wRa
# CQABAAACLTANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBAUazIFz+hlWNbh42NQrge8bz71z66jfg1
# HtE7K1Nq7jCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIHC+MbomstRUJwD0
# lacCJ4bDUrtTQ1kXR5Kfnekf/9FEMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTACEzMAAAItgb9r4uMEWgkAAQAAAi0wIgQgxFee4pA6xYnahpAt
# 0xWe/7Web/UP3xbuMqihsp9N1b8wDQYJKoZIhvcNAQELBQAEggIAOt2b3jiPzVUe
# 2s7J9LX9FReJsv4/0cV3aj1fbNLvN/aHRT0Ho7IiN/gPxT6ZnSBBJDM+SZQPCHak
# GpW6viMnAdI9nA7zgv+4VavxqWjmIsn7hxr6RjYdVW77rfY7LPgqFH/KMpSZkxZ4
# xN5/p8rXYNHKbzUbKPFuFpfHbC4ZWmBoywXfvjNOYQv3/vve5ak2wHsTb/pfvnYz
# 1n1HJfHaxYiDUWSDBY1miNhvp6Nnntkau+7Klr7APCkHXytJyTWEwcnfMds8/mbz
# qcpo/ailIQhUn5FScz1KA+6VlBzx/Py/bbYq436XicG9wbOXrYUgxIj9bPPEEaI/
# 8n2EOqfv2IpYGEWLhod1SCiAave1o6+WrnLmMW3LxZCF97SaEl1tpEYyLPBtxzgo
# p9JG/hCZeZGt5RENQBEnkfVKB7akUXeBSKwvOHOnqcJ13zXDLdFx6rCoUlL75wwK
# Us1Q/88TBEh6dRxaXOZOMxWwcdOl13T9COMmOxwAQKj7NzxGLeKQz8MVnNp7pHbf
# JC3qGCOldcSpBY60jowonk+0+LDIRyu+AJZ7UUC/jZZfB1o9Jb+xuONeUL75FFAT
# pbO9rbVz8lkGldCfwDbfkcnqiW4NyqTZ0pmctwfFkbPpbOaEEeMNb0STM1o59vQC
# rE1nwkBwQd/FZDuWai+sMdqexY+81rQ=
# SIG # End signature block
