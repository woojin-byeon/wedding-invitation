function Install-PackageUtility
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FastPackageReference,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $request
    )

    Set-ModuleSourcesVariable

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Install-PackageUtility'))

    Write-Debug ($LocalizedData.FastPackageReference -f $fastPackageReference)

    $Force = $false
    $SkipPublisherCheck = $false
    $AllowClobber = $false
    $Debug = $false
    $MinimumVersion = ""
    $RequiredVersion = ""
    $IsSavePackage = $false
    $Scope = $null
    $NoPathUpdate = $false
    $AcceptLicense = $false

    # take the fastPackageReference and get the package object again.
    $parts = $fastPackageReference -Split '[|]'

    if( $parts.Length -eq 5 )
    {
        $providerName = $parts[0]
        $packageName = $parts[1]
        $version = $parts[2]
        $sourceLocation= $parts[3]
        $artifactType = $parts[4]

        $result = ValidateAndGet-VersionPrereleaseStrings -Version $version -CallerPSCmdlet $PSCmdlet
        if (-not $result)
        {
            # ValidateAndGet-VersionPrereleaseStrings throws the error.
            # returning to avoid further execution when different values are specified for -ErrorAction parameter
            return
        }
        $galleryItemVersion = $result["Version"]
        $galleryItemPrerelease = $result["Prerelease"]
        $galleryItemFullVersion = $result["FullVersion"]

        # The default destination location for Modules and Scripts is ProgramFiles path
        $scriptDestination = $script:ProgramFilesScriptsPath
        $moduleDestination = $script:programFilesModulesPath
        $Scope = 'AllUsers'

        if($artifactType -eq $script:PSArtifactTypeScript)
        {
            $AdminPrivilegeErrorMessage = $LocalizedData.InstallScriptAdminPrivilegeRequiredForAllUsersScope -f @($script:ProgramFilesScriptsPath, $script:MyDocumentsScriptsPath)
            $AdminPrivilegeErrorId = 'InstallScriptAdminPrivilegeRequiredForAllUsersScope'
        }
        else
        {
            $AdminPrivilegeErrorMessage = $LocalizedData.InstallModuleAdminPrivilegeRequiredForAllUsersScope -f @($script:programFilesModulesPath, $script:MyDocumentsModulesPath)
            $AdminPrivilegeErrorId = 'InstallModuleAdminPrivilegeRequiredForAllUsersScope'
        }

        $installUpdate = $false

        $options = $request.Options

        if($options)
        {
            foreach( $o in $options.Keys )
            {
                Write-Debug ("OPTION: {0} => {1}" -f ($o, $request.Options[$o]) )
            }

            if($options.ContainsKey('Scope'))
            {
                $Scope = $options['Scope']
                Write-Verbose ($LocalizedData.SpecifiedInstallationScope -f $Scope)

                if($Scope -eq "CurrentUser")
                {
                    $scriptDestination = $script:MyDocumentsScriptsPath
                    $moduleDestination = $script:MyDocumentsModulesPath
                }
                elseif($Scope -eq "AllUsers")
                {
                    $scriptDestination = $script:ProgramFilesScriptsPath
                    $moduleDestination = $script:programFilesModulesPath

                    if(-not (Test-RunningAsElevated))
                    {
                        # Throw an error when Install-Module/Script is used as a non-admin user and '-Scope AllUsers'
                        ThrowError -ExceptionName "System.ArgumentException" `
                                    -ExceptionMessage $AdminPrivilegeErrorMessage `
                                    -ErrorId $AdminPrivilegeErrorId `
                                    -CallerPSCmdlet $PSCmdlet `
                                    -ErrorCategory InvalidArgument
                    }
                }
            }
            elseif($Location)
            {
                $IsSavePackage = $true
                $Scope = $null

                $moduleDestination = $Location
                $scriptDestination = $Location
            }
            elseif(-not $script:IsCoreCLR -and (Test-RunningAsElevated))
            {
                # If Windows and elevated default scope will be all users
                $scriptDestination = $script:ProgramFilesScriptsPath
                $moduleDestination = $script:ProgramFilesModulesPath
            }
            else
            {
                # If non-Windows or non-elevated default scope will be current user
                $scriptDestination = $script:MyDocumentsScriptsPath
                $moduleDestination = $script:MyDocumentsModulesPath
            }

            if($options.ContainsKey('SkipPublisherCheck'))
            {
                $SkipPublisherCheck = $options['SkipPublisherCheck']

                if($SkipPublisherCheck.GetType().ToString() -eq 'System.String')
                {
                    if($SkipPublisherCheck -eq 'true')
                    {
                        $SkipPublisherCheck = $true
                    }
                    else
                    {
                        $SkipPublisherCheck = $false
                    }
                }
            }

            if($options.ContainsKey('AllowClobber'))
            {
                $AllowClobber = $options['AllowClobber']

                if($AllowClobber.GetType().ToString() -eq 'System.String')
                {
                    if($AllowClobber -eq 'false')
                    {
                        $AllowClobber = $false
                    }
                    elseif($AllowClobber -eq 'true')
                    {
                        $AllowClobber = $true
                    }
                }
            }

            if($options.ContainsKey('Force'))
            {
                $Force = $options['Force']

                if($Force.GetType().ToString() -eq 'System.String')
                {
                    if($Force -eq 'false')
                    {
                        $Force = $false
                    }
                    elseif($Force -eq 'true')
                    {
                        $Force = $true
                    }
                }
            }

            if($options.ContainsKey('AcceptLicense'))
            {
                $AcceptLicense = $options['AcceptLicense']

                if($AcceptLicense.GetType().ToString() -eq 'System.String')
                {
                    if($AcceptLicense -eq 'false')
                    {
                        $AcceptLicense = $false
                    }
                    elseif($AcceptLicense -eq 'true')
                    {
                        $AcceptLicense = $true
                    }
                }
            }

            if($options.ContainsKey('Debug'))
            {
                $Debug = $options['Debug']

                if($Debug.GetType().ToString() -eq 'System.String')
                {
                    if($Debug -eq 'false')
                    {
                        $Debug = $false
                    }
                    elseif($Debug -eq 'true')
                    {
                        $Debug = $true
                    }
                }
            }

            if($options.ContainsKey('NoPathUpdate'))
            {
                $NoPathUpdate = $options['NoPathUpdate']

                if($NoPathUpdate.GetType().ToString() -eq 'System.String')
                {
                    if($NoPathUpdate -eq 'false')
                    {
                        $NoPathUpdate = $false
                    }
                    elseif($NoPathUpdate -eq 'true')
                    {
                        $NoPathUpdate = $true
                    }
                }
            }

            if($options.ContainsKey('MinimumVersion'))
            {
                $MinimumVersion = $options['MinimumVersion']
            }

            if($options.ContainsKey('RequiredVersion'))
            {
                $RequiredVersion = $options['RequiredVersion']
            }

            if($options.ContainsKey('InstallUpdate'))
            {
                $installUpdate = $options['InstallUpdate']

                if($installUpdate.GetType().ToString() -eq 'System.String')
                {
                    if($installUpdate -eq 'false')
                    {
                        $installUpdate = $false
                    }
                    elseif($installUpdate -eq 'true')
                    {
                        $installUpdate = $true
                    }
                }
            }

            if($Scope -and ($artifactType -eq $script:PSArtifactTypeScript) -and (-not $installUpdate))
            {
                ValidateAndSet-PATHVariableIfUserAccepts -Scope $Scope `
                                                         -ScopePath $scriptDestination `
                                                         -Request $request `
                                                         -NoPathUpdate:$NoPathUpdate `
                                                         -Force:$Force
            }

            if($artifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.ModuleDestination -f @($moduleDestination)
            }
            else
            {
                $message = $LocalizedData.ScriptDestination -f @($scriptDestination, $moduleDestination)
            }
            Write-Verbose $message
        }

        Write-Debug "ArtifactType is $artifactType"

        if($artifactType -eq $script:PSArtifactTypeModule)
        {
            # Test if module is already installed
            $InstalledModuleInfo = if(-not $IsSavePackage){ Test-ModuleInstalled -Name $packageName -RequiredVersion $RequiredVersion }

            if(-not $Force -and $InstalledModuleInfo)
            {
                $installedModPrerelease = $null
                if ((Get-Member -InputObject $InstalledModuleInfo -Name PrivateData -ErrorAction SilentlyContinue) -and `
                    $InstalledModuleInfo.PrivateData -and `
                    $InstalledModuleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and `
                    ($InstalledModuleInfo.PrivateData.ContainsKey('PSData')) -and `
                    $InstalledModuleInfo.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and `
                    ($InstalledModuleInfo.PrivateData.PSData.ContainsKey('Prerelease')))
                {
                    $installedModPrerelease = $InstalledModuleInfo.PrivateData.PSData.Prerelease
                }

                $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledModuleInfo.Version -Prerelease $installedModPrerelease -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $installedModuleVersion = $result["Version"]
                $installedModulePrerelease = $result["Prerelease"]
                $installedModuleFullVersion = $result["FullVersion"]

                if($RequiredVersion -and (Test-ModuleSxSVersionSupport))
                {
                    # Check if the module with the required version is already installed otherwise proceed to install/update.
                    if($InstalledModuleInfo)
                    {
                        $message = $LocalizedData.ModuleWithRequiredVersionAlreadyInstalled -f ($InstalledModuleInfo.Version, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase, $InstalledModuleInfo.Version)
                        Write-Error -Message $message -ErrorId "ModuleWithRequiredVersionAlreadyInstalled" -Category InvalidOperation
                        return
                    }
                }
                else
                {
                    if(-not $installUpdate)
                    {
                        if ($MinimumVersion)
                        {
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $MinimumVersion -CallerPSCmdlet $PSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $minVersion = $result["Version"]
                            $minPrerelease = $result["Prerelease"]
                            $minFullVersion = $result["FullVersion"]
                        }
                        else
                        {
                            $minVersion = $null
                            $minPrerelease = $null
                            $minFullVersion = $null
                        }

                        if( (-not $MinimumVersion -and ($galleryItemFullVersion -ne $InstalledModuleFullVersion)) -or
                            ($MinimumVersion -and (Compare-PrereleaseVersions -FirstItemVersion $installedModuleVersion `
                                                                              -FirstItemPrerelease $installedModulePrerelease `
                                                                              -SecondItemVersion $minVersion `
                                                                              -SecondItemPrerelease $minPrerelease)))
                        {
                            if($PSVersionTable.PSVersion -ge '5.0.0')
                            {
                                $message = $LocalizedData.ModuleAlreadyInstalledSxS -f ($InstalledModuleFullVersion, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase, $galleryItemFullVersion, $InstalledModuleFullVersion, $galleryItemFullVersion)
                            }
                            else
                            {
                                $message = $LocalizedData.ModuleAlreadyInstalled -f ($InstalledModuleFullVersion, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase, $InstalledModuleFullVersion, $galleryItemFullVersion)
                            }
                            Write-Error -Message $message -ErrorId "ModuleAlreadyInstalled" -Category InvalidOperation
                        }
                        else
                        {
                            $message = $LocalizedData.ModuleAlreadyInstalledVerbose -f ($InstalledModuleFullVersion, $InstalledModuleInfo.Name, $InstalledModuleInfo.ModuleBase)
                            Write-Verbose $message
                        }

                        return
                    }
                    else
                    {
                        if (Compare-PrereleaseVersions -FirstItemVersion $installedModuleVersion `
                                                       -FirstItemPrerelease $installedModulePrerelease `
                                                       -SecondItemVersion $galleryItemVersion.ToString() `
                                                       -SecondItemPrerelease $galleryItemPrerelease)
                        {
                            $message = $LocalizedData.FoundModuleUpdate -f ($InstalledModuleInfo.Name, $galleryItemFullVersion)
                            Write-Verbose $message
                        }
                        else
                        {
                            $message = $LocalizedData.NoUpdateAvailable -f ($InstalledModuleInfo.Name)
                            Write-Verbose $message
                            return
                        }
                    }
                }
            }
        }

        if($artifactType -eq $script:PSArtifactTypeScript)
        {
            # Test if script is already installed
            $InstalledScriptInfo = if(-not $IsSavePackage){ Test-ScriptInstalled -Name $packageName }

            Write-Debug "InstalledScriptInfo is $InstalledScriptInfo"

            if(-not $Force -and $InstalledScriptInfo)
            {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledScriptInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $installedScriptInfoVersion = $result["Version"]
                $installedScriptInfoPrerelease = $result["Prerelease"]
                $installedScriptFullVersion = $result["FullVersion"]

                if(-not $installUpdate)
                {
                    if ($MinimumVersion)
                    {
                        $result = ValidateAndGet-VersionPrereleaseStrings -Version $MinimumVersion -CallerPSCmdlet $PSCmdlet
                        if (-not $result)
                        {
                            # ValidateAndGet-VersionPrereleaseStrings throws the error.
                            # returning to avoid further execution when different values are specified for -ErrorAction parameter
                            return
                        }
                        $minVersion = $result["Version"]
                        $minPrerelease = $result["Prerelease"]
                        $minFullVersion = $result["FullVersion"]
                    }
                    else
                    {
                        $minVersion = $null
                        $minPrerelease = $null
                        $minFullVersion = $null
                    }


                    if( (-not $MinimumVersion -and ($galleryItemFullVersion -ne $installedScriptFullVersion)) -or
                        ($MinimumVersion -and (Compare-PrereleaseVersions -FirstItemVersion $installedScriptInfoVersion `
                                                                          -FirstItemPrerelease $installedScriptInfoPrerelease `
                                                                          -SecondItemVersion $minVersion `
                                                                          -SecondItemPrerelease $minPrerelease) ))
                    {
                        $message = $LocalizedData.ScriptAlreadyInstalled -f ($installedScriptFullVersion, $InstalledScriptInfo.Name, $InstalledScriptInfo.ScriptBase, $installedScriptFullVersion, $galleryItemFullVersion)
                        Write-Error -Message $message -ErrorId "ScriptAlreadyInstalled" -Category InvalidOperation
                    }
                    else
                    {
                        $message = $LocalizedData.ScriptAlreadyInstalledVerbose -f ($installedScriptFullVersion, $InstalledScriptInfo.Name, $InstalledScriptInfo.ScriptBase)
                        Write-Verbose $message
                    }

                    return
                }
                else
                {
                    if (Compare-PrereleaseVersions -FirstItemVersion $installedScriptInfoVersion.ToString() `
                                                   -FirstItemPrerelease $installedScriptInfoPrerelease `
                                                   -SecondItemVersion $galleryItemVersion.ToString() `
                                                   -SecondItemPrerelease $galleryItemPrerelease)
                    {
                        $message = $LocalizedData.FoundScriptUpdate -f ($InstalledScriptInfo.Name, $version)
                        Write-Verbose $message
                    }
                    else
                    {
                        $message = $LocalizedData.NoScriptUpdateAvailable -f ($InstalledScriptInfo.Name)
                        Write-Verbose $message
                        return
                    }
                }
            }

            # Throw an error if there is a command with the same name and -force is not specified.
            if(-not $installUpdate -and
               -not $IsSavePackage -and
               -not $Force)
            {
                $cmd = Microsoft.PowerShell.Core\Get-Command -Name $packageName `
                                                             -ErrorAction Ignore `
                                                             -WarningAction SilentlyContinue
                if($cmd)
                {
                    $message = $LocalizedData.CommandAlreadyAvailable -f ($packageName)
                    Write-Error -Message $message -ErrorId CommandAlreadyAvailableWitScriptName -Category InvalidOperation
                    return
                }
            }
        }

        # create a temp folder and download the module
        $tempDestination = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath "$(Microsoft.PowerShell.Utility\Get-Random)"
        $null = Microsoft.PowerShell.Management\New-Item -Path $tempDestination -ItemType Directory -Force -Confirm:$false -WhatIf:$false

        try
        {
            $provider = $request.SelectProvider($providerName)
            if(-not $provider)
            {
                Write-Error -Message ($LocalizedData.PackageManagementProviderIsNotAvailable -f $providerName)
                return
            }

            if($request.IsCanceled)
            {
                return
            }

            Write-Verbose ($LocalizedData.SpecifiedLocationAndOGP -f ($provider.ProviderName, $providerName))

            $InstalledItemsList = $null
            $pkg = $script:FastPackRefHashtable[$fastPackageReference]

            # If an item has dependencies, prepare the list of installed items and
            # pass it to the NuGet provider to not download the already installed items.
            if($pkg.Dependencies.count -and
               -not $IsSavePackage -and
               -not $Force)
            {
                $InstalledItemsList = Microsoft.PowerShell.Core\Get-Module -ListAvailable |
                                        Microsoft.PowerShell.Core\ForEach-Object {"$($_.Name)!#!$($_.Version)".ToLower()}

                if($artifactType -eq $script:PSArtifactTypeScript)
                {
                    $InstalledItemsList += $script:PSGetInstalledScripts.GetEnumerator() |
                                               Microsoft.PowerShell.Core\ForEach-Object {
                                                   "$($_.Value.PSGetItemInfo.Name)!#!$($_.Value.PSGetItemInfo.Version)".ToLower()
                                               }
                }

                $InstalledItemsList | Select-Object -Unique -ErrorAction Ignore

                if($Debug)
                {
                    $InstalledItemsList | Microsoft.PowerShell.Core\ForEach-Object { Write-Debug -Message "Locally available Item: $_"}
                }
            }

            $ProviderOptions = @{
                                    Destination=$tempDestination;
                                }

            if($InstalledItemsList)
            {
                $ProviderOptions['InstalledPackages'] = $InstalledItemsList
            }

            $newRequest = $request.CloneRequest( $ProviderOptions, @($SourceLocation), $request.Credential )

            if($artifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.DownloadingModuleFromGallery -f ($packageName, $galleryItemFullVersion, $sourceLocation)
            }
            else
            {
                $message = $LocalizedData.DownloadingScriptFromGallery -f ($packageName, $galleryItemFullVersion, $sourceLocation)
            }
            Write-Verbose $message

            $installedPkgs = $provider.InstallPackage($script:FastPackRefHashtable[$fastPackageReference], $newRequest)

            $YesToAll = $false
            $NoToAll = $false
           
            foreach($pkg in $installedPkgs)
            {
                if($request.IsCanceled)
                {
                    return
                }

                $result = ValidateAndGet-VersionPrereleaseStrings -Version $pkg.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $pkgVersion = $result["Version"]
                $pkgPrerelease = $result["Prerelease"]
                $pkgFullVersion = $result["FullVersion"]

                $destinationModulePath = Microsoft.PowerShell.Management\Join-Path -Path $moduleDestination -ChildPath $pkg.Name

                # Side-by-Side module version is available on PowerShell 5.0 or later versions only
                # By default, PowerShell module versions will be installed/updated Side-by-Side.
                if(Test-ModuleSxSVersionSupport)
                {
                    $destinationModulePath = Microsoft.PowerShell.Management\Join-Path -Path $destinationModulePath -ChildPath $pkgVersion
                }

                $destinationscriptPath = $scriptDestination

                # Get actual artifact type from the package
                $packageType = $script:PSArtifactTypeModule
                $installLocation = $destinationModulePath
                # Below logic handles the package folder name with version.
                $tempPackagePath = Microsoft.PowerShell.Management\Join-Path -Path $tempDestination -ChildPath "$($pkg.Name).$($pkg.Version)"
                if(-not (Microsoft.PowerShell.Management\Test-Path -Path $tempPackagePath -PathType Container))
                {
                    $message = $LocalizedData.UnableToDownloadThePackage -f ($provider.ProviderName, $pkg.Name, $pkg.Version, $tempPackagePath)
                    Write-Error -Message $message -ErrorId 'UnableToDownloadThePackage' -Category InvalidOperation
                    return
                }

                $packageFiles = Microsoft.PowerShell.Management\Get-ChildItem -Path $tempPackagePath -Recurse -Exclude "*.nupkg","*.nuspec"

                if($packageFiles -and $packageFiles.GetType().ToString() -eq 'System.IO.FileInfo' -and $packageFiles.Name -eq "$($pkg.Name).ps1")
                {
                    $packageType = $script:PSArtifactTypeScript
                    $installLocation = $destinationscriptPath
                }

                $AdditionalParams = @{}

                if(-not $IsSavePackage)
                {
                    # During the install operation:
                    #     InstalledDate should be the current Get-Date value
                    #     UpdatedDate should be null
                    #
                    # During the update operation:
                    #     InstalledDate should be from the previous version's InstalledDate otherwise current Get-Date value
                    #     UpdatedDate should be the current Get-Date value
                    #
                    $InstalledDate = Microsoft.PowerShell.Utility\Get-Date

                    if($installUpdate)
                    {
                        $AdditionalParams['UpdatedDate'] = Microsoft.PowerShell.Utility\Get-Date

                        $InstalledItemDetails = $null
                        if($packageType -eq $script:PSArtifactTypeModule)
                        {
                            $InstalledItemDetails = Get-InstalledModuleDetails -Name $pkg.Name | Select-Object -Last 1 -ErrorAction Ignore
                        }
                        elseif($packageType -eq $script:PSArtifactTypeScript)
                        {
                            $InstalledItemDetails = Get-InstalledScriptDetails -Name $pkg.Name | Select-Object -Last 1 -ErrorAction Ignore
                        }

                        if($InstalledItemDetails -and
                           $InstalledItemDetails.PSGetItemInfo -and
                           (Get-Member -InputObject $InstalledItemDetails.PSGetItemInfo -Name 'InstalledDate') -and
                           $InstalledItemDetails.PSGetItemInfo.InstalledDate)
                        {
                            $InstalledDate = $InstalledItemDetails.PSGetItemInfo.InstalledDate
                        }
                    }

                    $AdditionalParams['InstalledDate'] = $InstalledDate
                }

                # construct the PSGetItemInfo from SoftwareIdentity and persist it
                $psgItemInfo = New-PSGetItemInfo -SoftwareIdentity $pkg `
                                                 -PackageManagementProviderName $provider.ProviderName `
                                                 -SourceLocation $sourceLocation `
                                                 -Type $packageType `
                                                 -InstalledLocation $installLocation `
                                                 @AdditionalParams

                if($packageType -eq $script:PSArtifactTypeModule)
                {
                    if ($psgItemInfo.PowerShellGetFormatVersion -and
                        ($script:SupportedPSGetFormatVersionMajors -notcontains $psgItemInfo.PowerShellGetFormatVersion.Major))
                    {
                        $message = $LocalizedData.NotSupportedPowerShellGetFormatVersion -f ($psgItemInfo.Name, $psgItemInfo.PowerShellGetFormatVersion, $psgItemInfo.Name)
                        Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                        continue
                    }

                    $sourceModulePath = $tempPackagePath
                    if($psgItemInfo.PowerShellGetFormatVersion -eq "1.0")
                    {
                        $sourceModulePath = Microsoft.PowerShell.Management\Join-Path -Path $sourceModulePath -ChildPath 'Content' |
                            Microsoft.PowerShell.Management\Join-Path -ChildPath '*' |
                                Microsoft.PowerShell.Management\Join-Path -ChildPath $script:ModuleReferences |
                                    Microsoft.PowerShell.Management\Join-Path -ChildPath $pkg.Name
                    }

                    #Prompt if module requires license Acceptance
                    $requireLicenseAcceptance = $false
                    if($psgItemInfo.PowerShellGetFormatVersion -and
                       $psgItemInfo.PowerShellGetFormatVersion -ge $script:PSGetRequireLicenseAcceptanceFormatVersion)
                     {
                        if($psgItemInfo.AdditionalMetadata -and $psgItemInfo.AdditionalMetadata.requireLicenseAcceptance)
                        {
                              $requireLicenseAcceptance = $psgItemInfo.AdditionalMetadata.requireLicenseAcceptance
                        }
                    }

                    if($requireLicenseAcceptance -eq $true)
                    {
                        if($Force -and -not($AcceptLicense))
                        {
                            $message = $LocalizedData.ForceAcceptLicense -f $pkg.Name

                            ThrowError -ExceptionName "System.ArgumentException" `
                                       -ExceptionMessage $message `
                                       -ErrorId "ForceAcceptLicense" `
                                       -CallerPSCmdlet $PSCmdlet `
                                       -ErrorCategory InvalidArgument
                        }

                        If (-not ($YesToAll -or $NoToAll -or $AcceptLicense))
                        {
                            $LicenseFilePath = Join-PathUtility -Path $sourceModulePath -ChildPath 'License.txt' -PathType File
                            if(-not(Test-Path -Path $LicenseFilePath -PathType Leaf))
                            {
                                $message = $LocalizedData.LicenseTxtNotFound

                                ThrowError -ExceptionName "System.ArgumentException" `
                                           -ExceptionMessage $message `
                                           -ErrorId "LicenseTxtNotFound" `
                                           -CallerPSCmdlet $PSCmdlet `
                                           -ErrorCategory ObjectNotFound
                            }
                            $FormattedEula = (Get-Content -Path $LicenseFilePath) -Join "`r`n"
                            $message = $FormattedEula + "`r`n" + ($LocalizedData.AcceptanceLicenseQuery -f $pkg.Name)
                            $title = $LocalizedData.AcceptLicense
                            $result = $request.ShouldContinue($message, $title, [ref]$yesToAll, [ref]$NoToAll)
                            if(($result -eq $false) -or ($NoToAll -eq $true))
                            {
                                Write-Warning -Message $LocalizedData.UserDeclinedLicenseAcceptance
                                return
                            }
                        }
                    }

                    $CurrentModuleInfo = $null

                    # Validate the module
                    if(-not $IsSavePackage)
                    {
                        $CurrentModuleInfo = Test-ValidManifestModule -ModuleBasePath $sourceModulePath `
                                                                      -ModuleName $pkg.Name `
                                                                      -InstallLocation $InstallLocation `
                                                                      -AllowClobber:$AllowClobber `
                                                                      -SkipPublisherCheck:$SkipPublisherCheck `
                                                                      -IsUpdateOperation:$installUpdate

                        if(-not $CurrentModuleInfo)
                        {
                            Write-Verbose -Message ($LocalizedData.ModuleValidationFailed -f $ModuleName,$ModuleBasePath)
                            # This Install-Package provider API gets called once per an item/package/SoftwareIdentity.
                            # Return if there is an error instead of continuing further to install the dependencies or current module.
                            #
                            return
                        }
                    }

                    # Test if module is already installed
                    $InstalledModuleInfo2 = if(-not $IsSavePackage){ Test-ModuleInstalled -Name $pkg.Name -RequiredVersion $pkgFullVersion }

                    if($pkg.Name -ne $packageName)
                    {
                        if(-not $Force -and $InstalledModuleInfo2)
                        {
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledModuleInfo2.Version -CallerPSCmdlet $PSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $installedModuleVersion = $result["Version"]
                            $installedModulePrerelease = $result["Prerelease"]
                            $installedModuleFullVersion = $result["FullVersion"]

                            if(Test-ModuleSxSVersionSupport)
                            {
                                if($pkgFullVersion -eq $installedModuleFullVersion)
                                {
                                    if(-not $installUpdate)
                                    {
                                        $message = $LocalizedData.ModuleWithRequiredVersionAlreadyInstalled -f ($installedModuleFullVersion, $InstalledModuleInfo2.Name, $InstalledModuleInfo2.ModuleBase, $InstalledModuleFullVersion)
                                    }
                                    else
                                    {
                                        $message = $LocalizedData.NoUpdateAvailable -f ($pkg.Name)
                                    }

                                    Write-Verbose $message
                                    Continue
                                }
                            }
                            else
                            {
                                if(-not $installUpdate)
                                {
                                    $message = $LocalizedData.ModuleAlreadyInstalledVerbose -f ($InstalledModuleFullVersion, $InstalledModuleInfo2.Name, $InstalledModuleInfo2.ModuleBase)
                                    Write-Verbose $message
                                    Continue
                                }
                                else
                                {
                                    if(Compare-PrereleaseVersions -FirstItemVersion $installedModuleVersion.ToString() `
                                                                  -FirstItemPrerelease $installedModPrerelease `
                                                                  -SecondItemVersion $pkgVersion.ToString() `
                                                                  -SecondItemPrerelease $pkgPrerelease)
                                    {
                                        $message = $LocalizedData.FoundModuleUpdate -f ($pkg.Name, $pkgFullVersion)
                                        Write-Verbose $message
                                    }
                                    else
                                    {
                                        $message = $LocalizedData.NoUpdateAvailable -f ($pkg.Name)
                                        Write-Verbose $message
                                        Continue
                                    }
                                }
                            }
                        }

                        if($IsSavePackage)
                        {
                            $DependencyInstallMessage = $LocalizedData.SavingDependencyModule -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }
                        else
                        {
                            $DependencyInstallMessage = $LocalizedData.InstallingDependencyModule -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }

                        Write-Verbose  $DependencyInstallMessage
                    }

                    # check if module is in use
                    if($InstalledModuleInfo2)
                    {
                        $moduleInUse = Test-ModuleInUse -ModuleBasePath $InstalledModuleInfo2.ModuleBase `
                                                        -ModuleName $InstalledModuleInfo2.Name `
                                                        -ModuleVersion $InstalledModuleInfo2.Version `
                                                        -Verbose:$VerbosePreference `
                                                        -WarningAction $WarningPreference `
                                                        -ErrorAction $ErrorActionPreference `
                                                        -Debug:$DebugPreference

                        if($moduleInUse)
                        {
                            $message = $LocalizedData.ModuleIsInUse -f ($psgItemInfo.Name)
                            Write-Verbose $message
                            continue
                        }
                    }

                    # Use the actual module version retrieved from the module manifest.
                    if($CurrentModuleInfo -and (Test-ModuleSxSVersionSupport) -and -not $pkgPrerelease)
                    {
                        $destinationModulePath = Microsoft.PowerShell.Management\Join-Path -Path $moduleDestination -ChildPath $pkg.Name |
                            Microsoft.PowerShell.Management\Join-Path -ChildPath $CurrentModuleInfo.Version
                        $installLocation = $destinationModulePath
                        $psgItemInfo.InstalledLocation = $installLocation
                        $psgItemInfo.Version = $CurrentModuleInfo.Version
                    }

                    Copy-Module -SourcePath $sourceModulePath -DestinationPath $destinationModulePath -PSGetItemInfo $psgItemInfo -IsSavePackage:$IsSavePackage

                    if(-not $IsSavePackage)
                    {
                        # Write warning messages if externally managed module dependencies are not installed.
                        $ExternalModuleDependencies = Get-ExternalModuleDependencies -PSModuleInfo $CurrentModuleInfo
                        foreach($ExternalDependency in $ExternalModuleDependencies)
                        {
                            $depModuleInfo = Test-ModuleInstalled -Name $ExternalDependency

                            if(-not $depModuleInfo)
                            {
                                Write-Warning -Message ($LocalizedData.MissingExternallyManagedModuleDependency -f $ExternalDependency,$pkg.Name,$ExternalDependency)
                            }
                            else
                            {
                                Write-Verbose -Message ($LocalizedData.ExternallyManagedModuleDependencyIsInstalled -f $ExternalDependency)
                            }
                        }
                    }

                    if($IsSavePackage)
                    {
                        $message = $LocalizedData.ModuleSavedSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    else
                    {
                        $message = $LocalizedData.ModuleInstalledSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    Write-Verbose $message
                }


                if($packageType -eq $script:PSArtifactTypeScript)
                {
                    if ($psgItemInfo.PowerShellGetFormatVersion -and
                        ($script:SupportedPSGetFormatVersionMajors -notcontains $psgItemInfo.PowerShellGetFormatVersion.Major))
                    {
                        $message = $LocalizedData.NotSupportedPowerShellGetFormatVersionScripts -f ($psgItemInfo.Name, $psgItemInfo.PowerShellGetFormatVersion, $psgItemInfo.Name)
                        Write-Error -Message $message -ErrorId "NotSupportedPowerShellGetFormatVersion" -Category InvalidOperation
                        continue
                    }

                    $sourceScriptPath = Join-PathUtility -Path $tempPackagePath -ChildPath "$($pkg.Name).ps1" -PathType File

                    $currentScriptInfo = $null
                    if(-not $IsSavePackage)
                    {
                        # Validate the script
                        $currentScriptInfo = Test-ScriptFileInfo -Path $sourceScriptPath -ErrorAction SilentlyContinue

                        if(-not $currentScriptInfo)
                        {
                            $message = $LocalizedData.InvalidPowerShellScriptFile -f ($pkg.Name)
                            Write-Error -Message $message -ErrorId "InvalidPowerShellScriptFile" -Category InvalidOperation -TargetObject $pkg.Name
                            continue
                        }

                        # Use the version extracted from the script file.
                        $psgItemInfo.Version = $currentScriptInfo.Version
                    }

                    # Test if script is already installed
                    $InstalledScriptInfo2 = if(-not $IsSavePackage){ Test-ScriptInstalled -Name $pkg.Name }


                    if($pkg.Name -ne $packageName)
                    {
                        if(-not $Force -and $InstalledScriptInfo2)
                        {
                            $result = ValidateAndGet-VersionPrereleaseStrings -Version $InstalledScriptInfo2.Version -CallerPSCmdlet $PSCmdlet
                            if (-not $result)
                            {
                                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                                return
                            }
                            $installedScriptFullVersion = $result["FullVersion"]

                            if(-not $installUpdate)
                            {
                                $message = $LocalizedData.ScriptAlreadyInstalledVerbose -f ($InstalledScriptFullVersion, $InstalledScriptInfo2.Name, $InstalledScriptInfo2.ScriptBase)
                                Write-Verbose $message
                                Continue
                            }
                            else
                            {
                                if(Compare-PrereleaseVersions -FirstItemVersion $installedScriptInfoVersion.ToString() `
                                                              -FirstItemPrerelease $installedScriptInfoPrerelease `
                                                              -SecondItemVersion $pkgVersion `
                                                              -SecondItemPrerelease $pkgPrerelease)
                                {
                                    $message = $LocalizedData.FoundScriptUpdate -f ($pkg.Name, $pkgFullVersion)
                                    Write-Verbose $message
                                }
                                else
                                {
                                    $message = $LocalizedData.NoScriptUpdateAvailable -f ($pkg.Name)
                                    Write-Verbose $message
                                    Continue
                                }
                            }
                        }

                        if($IsSavePackage)
                        {
                            $DependencyInstallMessage = $LocalizedData.SavingDependencyScript -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }
                        else
                        {
                            $DependencyInstallMessage = $LocalizedData.InstallingDependencyScript -f ($pkg.Name, $pkgFullVersion, $packageName)
                        }

                        Write-Verbose  $DependencyInstallMessage
                    }

                    Write-Debug "SourceScriptPath is $sourceScriptPath and DestinationscriptPath is $destinationscriptPath"
                    Copy-ScriptFile -SourcePath $sourceScriptPath -DestinationPath $destinationscriptPath -PSGetItemInfo $psgItemInfo -Scope $Scope

                    if(-not $IsSavePackage)
                    {
                        # Write warning messages if externally managed module dependencies are not installed.
                        foreach($ExternalDependency in $currentScriptInfo.ExternalModuleDependencies)
                        {
                            $depModuleInfo = Test-ModuleInstalled -Name $ExternalDependency

                            if(-not $depModuleInfo)
                            {
                                Write-Warning -Message ($LocalizedData.ScriptMissingExternallyManagedModuleDependency -f $ExternalDependency,$pkg.Name,$ExternalDependency)
                            }
                            else
                            {
                                Write-Verbose -Message ($LocalizedData.ExternallyManagedModuleDependencyIsInstalled -f $ExternalDependency)
                            }
                        }

                        # Write warning messages if externally managed script dependencies are not installed.
                        foreach($ExternalDependency in $currentScriptInfo.ExternalScriptDependencies)
                        {
                            $depScriptInfo = Test-ScriptInstalled -Name $ExternalDependency

                            if(-not $depScriptInfo)
                            {
                                Write-Warning -Message ($LocalizedData.ScriptMissingExternallyManagedScriptDependency -f $ExternalDependency,$pkg.Name,$ExternalDependency)
                            }
                            else
                            {
                                Write-Verbose -Message ($LocalizedData.ScriptExternallyManagedScriptDependencyIsInstalled -f $ExternalDependency)
                            }
                        }
                    }

                    # Remove the old scriptfile if it's path different from the required destination script path when -Force is specified
                    if($Force -and
                        $InstalledScriptInfo2 -and
                        -not $destinationscriptPath.StartsWith($InstalledScriptInfo2.ScriptBase, [System.StringComparison]::OrdinalIgnoreCase))
                    {
                        Microsoft.PowerShell.Management\Remove-Item -Path $InstalledScriptInfo2.Path `
                                                                    -Force `
                                                                    -ErrorAction SilentlyContinue `
                                                                    -WarningAction SilentlyContinue `
                                                                    -Confirm:$false -WhatIf:$false
                    }

                    if($IsSavePackage)
                    {
                        $message = $LocalizedData.ScriptSavedSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    else
                    {
                        $message = $LocalizedData.ScriptInstalledSuccessfully -f ($psgItemInfo.Name, $installLocation)
                    }
                    Write-Verbose $message
                }

                $sid = New-SoftwareIdentityFromPackage -Package $pkg `
                    -SourceLocation $sourceLocation `
                    -PackageManagementProviderName $provider.ProviderName `
                    -Request $request `
                    -Type $packageType `
                    -InstalledLocation $installLocation `
                    @AdditionalParams

                Write-Output -InputObject $sid
            }
        }
        finally
        {
            Microsoft.PowerShell.Management\Remove-Item $tempDestination -Force -Recurse -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }
}
# SIG # Begin signature block
# MIInOQYJKoZIhvcNAQcCoIInKjCCJyYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCDB07REFFrCgnk
# fieG1PaY08WZ2xpf6l03tSdM2twobaCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEILX7r5/+HFJ6VZjJr4+GT/5EajUz
# tVEbvU/UrZ7xlSdGMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAbUyQE/5R9A0Wr5mtrucI8XYNAKypNBvStCaj/MFdanoj12Rr3FQ6psGiK6nK
# gyHzvQp6kGsfvLcfYf0Hmvv2w2xd0kX/dkaBVfM5xe0igUBQb5hfWHHBxZV2+Vso
# huIGMol1OTdCgxzuOm4brjlh4WRuNaqM47TKoXyf1GjQ74ZFVhNOznQEgdd83Fvk
# +cXuKww/UTUyvjpZHstZKHLu9+RJ+kTsrsNBQPAzTAUCBWWEggQNDF2gReH6Vspm
# CFEI7D4RJS3kiU4CPzZTPTYPKgeHHtK+y/Fbo8ZIM46Y8+bFTXv0lDuUNhEVr4gM
# moDlEeAL6EJf/9vmyfpICy7v7KGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34G
# CSqGSIb3DQEHAqCCF28wghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCA80duazP159Td6yOW0dxuFlXmbXPtckzosg1wkSiNkYgIGavNt1McGGBMy
# MDI2MTExMDIyMDUyNC4zODRaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
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
# KoZIhvcNAQkEMSIEIGy+ZROotQS0gYwlH4TNTpsiCkm9nPLYXXpdssG5HG9tMIH6
# BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQg5ecBGjWhUhw4skoOqUTRp2r+Nn1N
# d2WddZFxcZOEEXIwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAifVwIPDsS5XLQABAAACJzAiBCBXWLIwmxP1mWrYgCOt0tUsypAno7r8
# Bk6s4EiunbuJ1DANBgkqhkiG9w0BAQsFAASCAgBbKcDlOkE4M0MNLgOgmjuMzhFi
# P9MDK2Vvd3xr+bpQmoMmONpHcxH06Zhr6kzWDQzRpNa+DgrBxph0yPf2s2nNyHQp
# 6/hvFoy7tLB7nqmrO8+Ms+l1PEyU1pJEX9OXHMuJygzeqOQj9NJUG37jjYizl8s4
# kWzBXuJcLAaYciyrNyiZLqf1GBFLtOiZiLC6uJ5t5f+pvS9GUx0FSFY8Uf07vHq+
# sLZL/NPlztluwHDmSeUtIpG7WNr3Vu6FuXcE7VIO6JDFif3fVpasgNvulKQY6omP
# qsUdP9Rwb383lGNElWbN+j5jUCM+b0elH5K7BlXqU9o//cRYq/Jglmgpn7iT8JZ0
# SkY1j0CWLVMAQQ5cnE0UR7S4LaV3lPL7nQzKjseRGuV9V64ngCME2p8Goicf5JIH
# wbDCvN0jBG9PenyuJRP2HpKZ0jR+vWjoPg5mtd24Souawf3130VrxU4PFTMOcsiZ
# MMmbA74BrqF3Ew4RlW/iyKB2VAFChKU3MHdoLojkh+3hzGNyOi1wEXC0Lcd8xR+6
# UoUZSichHA5A5CTkG4S0bEKvrcgdhPg4BTcrb+mhjIkKJF1M4CtVheovQo5n82CQ
# o0KpY/NCCYzedVp96n9kzykuJBmtmgSY6stSMZtaRrjYTfwMpzZEgH0BVgDJJJpj
# OUs641+wdYtOKGKg5A==
# SIG # End signature block
