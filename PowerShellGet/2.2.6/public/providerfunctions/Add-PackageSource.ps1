function Add-PackageSource
{
    [CmdletBinding()]
    param
    (
        [string]
        $Name,

        [string]
        $Location,

        [bool]
        $Trusted
    )

    Write-Debug ($LocalizedData.ProviderApiDebugMessage -f ('Add-PackageSource'))

    if(-not $Name)
    {
        return
    }

    $Credential = $request.Credential

    $IsNewModuleSource = $false
    $Options = $request.Options

    foreach( $o in $Options.Keys )
    {
        Write-Debug ( "OPTION: {0} => {1}" -f ($o, $Options[$o]) )
    }

    $Proxy = $null
    if($Options.ContainsKey($script:Proxy))
    {
        $Proxy = $Options[$script:Proxy]

        if(-not (Test-WebUri -Uri $Proxy))
        {
            $message = $LocalizedData.InvalidWebUri -f ($Proxy, $script:Proxy)
            ThrowError -ExceptionName 'System.ArgumentException' `
                        -ExceptionMessage $message `
                        -ErrorId 'InvalidWebUri' `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $Proxy
        }
    }

    $ProxyCredential = $null
    if($Options.ContainsKey($script:ProxyCredential))
    {
        $ProxyCredential = $Options[$script:ProxyCredential]
    }

    Set-ModuleSourcesVariable -Force -Proxy $Proxy -ProxyCredential $ProxyCredential

    if($Options.ContainsKey('IsNewModuleSource'))
    {
        $IsNewModuleSource = $Options['IsNewModuleSource']

        if($IsNewModuleSource.GetType().ToString() -eq 'System.String')
        {
            if($IsNewModuleSource -eq 'false')
            {
                $IsNewModuleSource = $false
            }
            elseif($IsNewModuleSource -eq 'true')
            {
                $IsNewModuleSource = $true
            }
        }
    }

    $IsUpdatePackageSource = $false
    if($Options.ContainsKey('IsUpdatePackageSource'))
    {
        $IsUpdatePackageSource = $Options['IsUpdatePackageSource']

        if($IsUpdatePackageSource.GetType().ToString() -eq 'System.String')
        {
            if($IsUpdatePackageSource -eq 'false')
            {
                $IsUpdatePackageSource = $false
            }
            elseif($IsUpdatePackageSource -eq 'true')
            {
                $IsUpdatePackageSource = $true
            }
        }
    }

    $PublishLocation = $null
    if($Options.ContainsKey($script:PublishLocation))
    {
        if($Name -eq $Script:PSGalleryModuleSource)
        {
            $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('PublishLocation')
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $PublishLocation
        }

        $PublishLocation = $Options[$script:PublishLocation]

        if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $PublishLocation) -and
           -not (Test-WebUri -uri $PublishLocation))
        {
            $PublishLocationUri = [Uri]$PublishLocation
            if($PublishLocationUri.Scheme -eq 'file')
            {
                $message = $LocalizedData.PathNotFound -f ($PublishLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "PathNotFound" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $PublishLocation
            }
            else
            {
                $message = $LocalizedData.InvalidWebUri -f ($PublishLocation, "PublishLocation")
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidWebUri" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $PublishLocation
            }
        }
    }

    $ScriptSourceLocation = $null
    if($Options.ContainsKey($script:ScriptSourceLocation))
    {
        if($Name -eq $Script:PSGalleryModuleSource)
        {
            $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('ScriptSourceLocation')
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $ScriptSourceLocation
        }

        $ScriptSourceLocation = $Options[$script:ScriptSourceLocation]

        if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptSourceLocation) -and
           -not (Test-WebUri -uri $ScriptSourceLocation))
        {
            $ScriptSourceLocationUri = [Uri]$ScriptSourceLocation
            if($ScriptSourceLocationUri.Scheme -eq 'file')
            {
                $message = $LocalizedData.PathNotFound -f ($ScriptSourceLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "PathNotFound" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptSourceLocation
            }
            else
            {
                $message = $LocalizedData.InvalidWebUri -f ($ScriptSourceLocation, "ScriptSourceLocation")
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidWebUri" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptSourceLocation
            }
        }
    }

    $ScriptPublishLocation = $null
    if($Options.ContainsKey($script:ScriptPublishLocation))
    {
        if($Name -eq $Script:PSGalleryModuleSource)
        {
            $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('ScriptPublishLocation')
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $ScriptPublishLocation
        }

        $ScriptPublishLocation = $Options[$script:ScriptPublishLocation]

        if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptPublishLocation) -and
           -not (Test-WebUri -uri $ScriptPublishLocation))
        {
            $ScriptPublishLocationUri = [Uri]$ScriptPublishLocation
            if($ScriptPublishLocationUri.Scheme -eq 'file')
            {
                $message = $LocalizedData.PathNotFound -f ($ScriptPublishLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "PathNotFound" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptPublishLocation
            }
            else
            {
                $message = $LocalizedData.InvalidWebUri -f ($ScriptPublishLocation, "ScriptPublishLocation")
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidWebUri" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $ScriptPublishLocation
            }
        }
    }

    $currentSourceObject = $null

    # Check if Name is already registered
    if($script:PSGetModuleSources.Contains($Name))
    {
        $currentSourceObject = $script:PSGetModuleSources[$Name]
    }

    # Location is not allowed for PSGallery source
    # However OneGet passes Location value during Set-PackageSource cmdlet,
    # that's why ensuring that Location value is same as the current SourceLocation
    #
    if(($Name -eq $Script:PSGalleryModuleSource) -and
       $Location -and
       ((-not $IsUpdatePackageSource) -or ($currentSourceObject -and $currentSourceObject.SourceLocation -ne $Location)))
    {
        $message = $LocalizedData.ParameterIsNotAllowedWithPSGallery -f ('Location, NewLocation or SourceLocation')
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId 'ParameterIsNotAllowedWithPSGallery' `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument `
                   -ExceptionObject $Location
    }

    if($Name -eq $Script:PSGalleryModuleSource)
    {
        # Add or update the PSGallery repository
        $repository = Set-PSGalleryRepository -Trusted:$Trusted

        if($repository)
        {
            # return the package source object.
            Write-Output -InputObject (New-PackageSourceFromModuleSource -ModuleSource $repository)
        }

        return
    }

    if($Location)
    {
        # Ping and resolve the specified location
        $Location = Resolve-Location -Location $Location `
                                     -LocationParameterName 'Location' `
                                     -Credential $Credential `
                                     -Proxy $Proxy `
                                     -ProxyCredential $ProxyCredential `
                                     -CallerPSCmdlet $PSCmdlet
    }

    if(-not $Location)
    {
        # Above Resolve-Location function throws an error when it is not able to resolve a location
        return
    }

    if(-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Location) -and
       -not (Test-WebUri -uri $Location) )
    {
        $LocationUri = [Uri]$Location
        if($LocationUri.Scheme -eq 'file')
        {
            $message = $LocalizedData.PathNotFound -f ($Location)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "PathNotFound" `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $Location
        }
        else
        {
            $message = $LocalizedData.InvalidWebUri -f ($Location, "Location")
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "InvalidWebUri" `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument `
                       -ExceptionObject $Location
        }
    }

    if(Test-WildcardPattern $Name)
    {
        $message = $LocalizedData.RepositoryNameContainsWildCards -f ($Name)
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "RepositoryNameContainsWildCards" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument `
                    -ExceptionObject $Name
    }

    $LocationString = Get-ValidModuleLocation -LocationString $Location -ParameterName "Location" -Proxy $Proxy -ProxyCredential $ProxyCredential -Credential $Credential

    # Check if Location is already registered with another Name
    $existingSourceName = Get-SourceName -Location $LocationString

    if($existingSourceName -and
       ($Name -ne $existingSourceName) -and
       -not $IsNewModuleSource)
    {
        $message = $LocalizedData.RepositoryAlreadyRegistered -f ($existingSourceName, $Location, $Name)
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "RepositoryAlreadyRegistered" `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
    }

    if(-not $PublishLocation -and $currentSourceObject -and $currentSourceObject.PublishLocation)
    {
        $PublishLocation = $currentSourceObject.PublishLocation
    }

    if((-not $ScriptPublishLocation) -and
       $currentSourceObject -and
       (Get-Member -InputObject $currentSourceObject -Name $script:ScriptPublishLocation) -and
       $currentSourceObject.ScriptPublishLocation)
    {
        $ScriptPublishLocation = $currentSourceObject.ScriptPublishLocation
    }

    if((-not $ScriptSourceLocation) -and
       $currentSourceObject -and
       (Get-Member -InputObject $currentSourceObject -Name $script:ScriptSourceLocation) -and
       $currentSourceObject.ScriptSourceLocation)
    {
        $ScriptSourceLocation = $currentSourceObject.ScriptSourceLocation
    }

    $IsProviderSpecified = $false;
    if ($Options.ContainsKey($script:PackageManagementProviderParam))
    {
        $SpecifiedProviderName = $Options[$script:PackageManagementProviderParam]

        $IsProviderSpecified = $true

        Write-Verbose ($LocalizedData.SpecifiedProviderName -f $SpecifiedProviderName)
        if ($SpecifiedProviderName -eq $script:PSModuleProviderName)
        {
            $message = $LocalizedData.InvalidPackageManagementProviderValue -f ($SpecifiedProviderName, $script:NuGetProviderName, $script:NuGetProviderName)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidPackageManagementProviderValue" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $SpecifiedProviderName
            return
        }
    }
    else
    {
        $SpecifiedProviderName = $script:NuGetProviderName
        Write-Verbose ($LocalizedData.ProviderNameNotSpecified -f $SpecifiedProviderName)
    }

    $packageSource = $null

    $selProviders = $request.SelectProvider($SpecifiedProviderName)

    if(-not $selProviders -and $IsProviderSpecified)
    {
        $message = $LocalizedData.SpecifiedProviderNotAvailable -f $SpecifiedProviderName
        ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedProviderNotAvailable" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $SpecifiedProviderName
    }

    # Try with user specified provider or NuGet provider
    foreach($SelectedProvider in $selProviders)
    {
        if($request.IsCanceled)
        {
            return
        }

        if($SelectedProvider -and $SelectedProvider.Features.ContainsKey($script:SupportsPSModulesFeatureName))
        {
            $NewRequest = $request.CloneRequest( $null, @($LocationString), $request.Credential )
            $packageSource = $SelectedProvider.ResolvePackageSources( $NewRequest )
        }
        else
        {
            $message = $LocalizedData.SpecifiedProviderDoesnotSupportPSModules -f $SelectedProvider.ProviderName
            ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "SpecifiedProviderDoesnotSupportPSModules" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidOperation `
                        -ExceptionObject $SelectedProvider.ProviderName
        }

        if($packageSource)
        {
            break
        }
    }

    # Poll other package provider when NuGet provider doesn't resolves the specified location
    if(-not $packageSource -and -not $IsProviderSpecified)
    {
        Write-Verbose ($LocalizedData.PollingPackageManagementProvidersForLocation -f $LocationString)

        $moduleProviders = $request.SelectProvidersWithFeature($script:SupportsPSModulesFeatureName)

        foreach($provider in $moduleProviders)
        {
            if($request.IsCanceled)
            {
                return
            }

            # Skip already tried $SpecifiedProviderName and PowerShellGet provider
            if($provider.ProviderName -eq $SpecifiedProviderName -or
               $provider.ProviderName -eq $script:PSModuleProviderName)
            {
                continue
            }

            Write-Verbose ($LocalizedData.PollingSingleProviderForLocation -f ($LocationString, $provider.ProviderName))
            $NewRequest = $request.CloneRequest( @{}, @($LocationString), $request.Credential )
            $packageSource = $provider.ResolvePackageSources($NewRequest)

            if($packageSource)
            {
                Write-Verbose ($LocalizedData.FoundProviderForLocation -f ($provider.ProviderName, $Location))
                $SelectedProvider = $provider
                break
            }
        }
    }

    if(-not $packageSource)
    {
        $message = $LocalizedData.SpecifiedLocationCannotBeRegistered -f $Location
        ThrowError -ExceptionName "System.InvalidOperationException" `
                    -ExceptionMessage $message `
                    -ErrorId "SpecifiedLocationCannotBeRegistered" `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidOperation `
                    -ExceptionObject $Location
    }

    $ProviderOptions = @{}

    $SelectedProvider.DynamicOptions | Microsoft.PowerShell.Core\ForEach-Object {
                                            if($options.ContainsKey($_.Name) )
                                            {
                                                $ProviderOptions[$_.Name] = $options[$_.Name]
                                            }
                                       }

    # Keep the existing provider options if not specified in Set-PSRepository
    if($currentSourceObject)
    {
        $currentSourceObject.ProviderOptions.GetEnumerator() | Microsoft.PowerShell.Core\ForEach-Object {
                                                                   if (-not $ProviderOptions.ContainsKey($_.Key) )
                                                                   {
                                                                       $ProviderOptions[$_.Key] = $_.Value
                                                                   }
                                                               }
    }

    if(-not $PublishLocation)
    {
        $PublishLocation = Get-PublishLocation -Location $LocationString
    }

    # Use the PublishLocation for the scripts when ScriptPublishLocation is not specified by the user
    if(-not $ScriptPublishLocation)
    {
        $ScriptPublishLocation = $PublishLocation

        # ScriptPublishLocation and PublishLocation should be equal in case of SMB Share or Local directory paths
        if($Options.ContainsKey($script:ScriptPublishLocation) -and
           (Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptPublishLocation))
        {
            if($ScriptPublishLocation -ne $PublishLocation)
            {
                $message = $LocalizedData.PublishLocationPathsForModulesAndScriptsShouldBeEqual -f ($LocationString, $ScriptSourceLocation)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "PublishLocationPathsForModulesAndScriptsShouldBeEqual" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation `
                            -ExceptionObject $Location
            }
        }
    }

    if(-not $ScriptSourceLocation)
    {
        $ScriptSourceLocation = Get-ScriptSourceLocation -Location $LocationString -Proxy $Proxy -ProxyCredential $ProxyCredential -Credential $Credential
    }
    elseif($Options.ContainsKey($script:ScriptSourceLocation))
    {
        # ScriptSourceLocation and SourceLocation should be equal for SMB Share or Local directory paths
        if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $ScriptSourceLocation)
        {
            if($ScriptSourceLocation -ne $LocationString)
            {
                $message = $LocalizedData.SourceLocationPathsForModulesAndScriptsShouldBeEqual -f ($LocationString, $ScriptSourceLocation)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "SourceLocationPathsForModulesAndScriptsShouldBeEqual" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidOperation `
                            -ExceptionObject $Location
            }
        }
    }

    # no error so we can safely remove the source
    if($script:PSGetModuleSources.Contains($Name))
    {
        $null = $script:PSGetModuleSources.Remove($Name)
    }

    # Add new module source
    $moduleSource = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
            Name = $Name
            SourceLocation = $LocationString
            PublishLocation = $PublishLocation
            ScriptSourceLocation = $ScriptSourceLocation
            ScriptPublishLocation = $ScriptPublishLocation
            Trusted=$Trusted
            Registered= (-not $IsNewModuleSource)
            InstallationPolicy = if($Trusted) {'Trusted'} else {'Untrusted'}
            PackageManagementProvider = $SelectedProvider.ProviderName
            ProviderOptions = $ProviderOptions
        })

    #region telemetry - Capture non-PSGallery registrations as telemetry events
    if ($script:TelemetryEnabled)
    {

        Log-NonPSGalleryRegistration -sourceLocation $moduleSource.SourceLocation `
                                     -installationPolicy $moduleSource.InstallationPolicy `
                                     -packageManagementProvider $moduleSource.PackageManagementProvider `
                                     -publishLocation $moduleSource.PublishLocation `
                                     -scriptSourceLocation $moduleSource.ScriptSourceLocation `
                                     -scriptPublishLocation $moduleSource.ScriptPublishLocation `
                                     -operationName PSGET_NONPSGALLERY_REGISTRATION `
                                     -ErrorAction SilentlyContinue `
                                     -WarningAction SilentlyContinue

    }
    #endregion

    $moduleSource.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSRepository")

    # Persist the repositories only when Register-PSRepository cmdlet is used
    if(-not $IsNewModuleSource)
    {
        $script:PSGetModuleSources.Add($Name, $moduleSource)

        $message = $LocalizedData.RepositoryRegistered -f ($Name, $LocationString)
        Write-Verbose $message

        # Persist the module sources
        Save-ModuleSources
    }

    # return the package source object.
    Write-Output -InputObject (New-PackageSourceFromModuleSource -ModuleSource $moduleSource)
}

# SIG # Begin signature block
# MIInOAYJKoZIhvcNAQcCoIInKTCCJyUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAnhn1cZ8+TPvDK
# Yec8K/S30F2e4mH2VZ+9ZrNKzjVZV6CCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghnFMIIZwQIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCggZAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIDxzptK7vdEH/ETCThnk06lMHjmr
# T/f8OWrqOjeZfp76MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEASiHHbW9W7mPKw5wH4RECJdDCLsVGXfATQd4ys2nz4Zi00rhYfcA/z9HeJkuz
# FavE52pHCb3nLbSYp9jeaG+uLE2DhFUgj0QrcQn1d7ZfIiaXdsIOgMo7b+kYjLfE
# QNzTKw7/3Wp7cg6G43OmmabCGsS2HHsIC9YS7V8JUsXrJxOEmPdS+VoKigxlz8UU
# OeR/tqN9WjSEjSXXvZzMv3qlQyxBZjVq7f6ADyCLTBlZ1g/cDcyMcSnqI64jO2mx
# cLenbyeYaNV4jeWqI7RxbS/M0D5x4mccE5LPNetb1HWLXakPGaa9b4N8UAS4Jjuh
# vXuzXdfQ4JJ3I8mf0kStRszZR6GCF5UwgheRBgorBgEEAYI3AwMBMYIXgTCCF30G
# CSqGSIb3DQEHAqCCF24wghdqAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG
# 9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCB5hOoz8w0mVRuIstkUsO2ilDXElsdDWwCtPV8pCpROaQIGavNszyXGGBIy
# MDI2MTExMDIyMDU1My45N1owBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNh
# IE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RjAwLTA1RTAt
# RDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEeww
# ggcgMIIFCKADAgECAhMzAAACHqOspG45b3xJAAEAAAIeMA0GCSqGSIb3DQEBCwUA
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI2MDIxOTE5Mzk0OVoX
# DTI3MDUxNzE5Mzk0OVowgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAl
# BgNVBAsTHm5TaGllbGQgVFNTIEVTTjo3RjAwLTA1RTAtRDk0NzElMCMGA1UEAxMc
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAKXROO1sPCxHsV7xpzqiXmzXOG1Op3YBalyFCEun0bmaZIzb
# c3l/JAYJDUPTqs4Dc+BcoX7vq9e84KzZWwu/WjCPiYcTISqKrwYnnIL79A1hGlk8
# Dx7s6B6TMM7pL/i/L+NMxhuneuG4WIooLNNY5C10VwX4PSTfr0jumb8TTtLI0waS
# 413mWPlIn3VSoW5l+MwHpxDbCHvua2JFRV2PnfKN02qP4ZCX5hrPb0GOvOftTWWf
# 4mkuWdvTF0aZmgg8plvAFVxa3Ivi7KEwvtJJOaI59ZdT6D7I2XQJ2gsYvwu1YcSL
# wWy5M95J1KqZ4yu8toSaJtNVNLi9BBjw0+dvq4jnLqI1X28EVybwtT+UNOMZOo9r
# tQFPiB1/kmbfBit8IVng/+PkyipPQk41xrnSO3hMYj3RKKFdoMRiqTbdLQglndSR
# Sm6QNFOMrvXcEjKR9/HIGox5Cp87TO9Z9THsGuZSm6BBzD334PEuXaB/65ASlGae
# VutUn129b12zh+oQ83aMbRDAXU8FKCU1xXVKmpkqK1CAEZLC7/zYArO2gIfBhEdE
# 3DPBNV7/Uo1O+aoB3hSB6zjLA4fTaFpqBPzBhjw51Z2MqfeTTnbD6SZzRQLQX6JV
# dMZkgzG+j2IFlChd6HNG1Yn9U60q8LJLdywrM3utK1YnCNJbPp205/SX7K0tAgMB
# AAGjggFJMIIBRTAdBgNVHQ4EFgQU5goWmuoEHQlmYlwULhw8+Z4XgmQwHwYDVR0j
# BBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGlt
# ZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggr
# BgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9N
# aWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0T
# AQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4Aw
# DQYJKoZIhvcNAQELBQADggIBAKShkHk2clUVvnAp6NGieTnXxrZME1ikpwEy18vo
# FLQBFoAE4wZguU826EjUfCZ6U/2FfeirdNoSb9wOSTM1ADMN50+ChEjZHv7ymg1J
# a8dcQCztJk4Ob3HsqqUGQ1kz17HhdjXI2ZU4CZYONGvuMqNqJBue1/sQLgY2KTEY
# ZpVY6N9i3dD1fSv8qzwoGVvMNH3OMD9MJy1HhyjValTVlEsWsH1uXx1HGxufJPap
# DjUTt1PXZHfR4gZTOISzkY37bpX+i9c6LbR0mIzXeFha/LU00kCGQo6UsHU426d3
# p9+E91Rwday7xX6VHRpqQxXrgeoNsu6ZmsI3BSh9XHfEyTwXi0Jgm1DEtPLBzfSx
# kAPVLawLX3n3HoqLED6njUUtSXyDrigfLdt9icfnF3gk4GBChqqd0aNxy3Gv7wSS
# eOErKuADOtNwosltR7OCjJ7xusIsn7Lo8CgSOldGRJgBTzB9DdhZFyToAvChXtSK
# fz6ukZBJteEXpzV1MVqReYKEKW53ggANj+3olGQn7ToXMv6MN3wotXxCPvsl+K5O
# I8gbkb/GWcahkVxf7LIG0O/NkTjx35j4dhR39y+EfUUqXsAf7kDKi2olIWa8z8G5
# hHHYHbRqxVeKVXaTYls07csYLPdD52kSXPCx8muRrU3+B62Zrt9amjCw2+ghoRC+
# Np3xMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0B
# AQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAG
# A1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAw
# HhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOTh
# pkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xP
# x2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ
# 3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOt
# gFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYt
# cI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXA
# hjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0S
# idb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSC
# D/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEB
# c8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh
# 8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8Fdsa
# N8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkr
# BgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q
# /y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBR
# BgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAP
# BgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjE
# MFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kv
# Y3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEF
# BQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEB
# CwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnX
# wnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOw
# Bb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jf
# ZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ
# 5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+
# ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgs
# sU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6
# OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p
# /cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6
# TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784
# cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA08wggI3
# AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYD
# VQQLEx5uU2hpZWxkIFRTUyBFU046N0YwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAIP9A2Qo
# MhbhUgXuPeiLaputHRr/oIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwDQYJKoZIhvcNAQELBQACBQDunetLMCIYDzIwMjYxMTEwMTkxMzE1WhgP
# MjAyNjExMTExOTEzMTVaMHYwPAYKKwYBBAGEWQoEATEuMCwwCgIFAO6d60sCAQAw
# CQIBAAIBEQIB/zAHAgEAAgIQeDAKAgUA7p88ywIBADA2BgorBgEEAYRZCgQCMSgw
# JjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3
# DQEBCwUAA4IBAQBQzy+Bbk7w0iSDNdV7WvZkfYFQDmHP5buXliW4GA5c7TrB+knp
# V2WsjOhkoLU+20a9AnkpXgvVy/1Ly8naB9udaSl21ORInJUHa0hpqsqviHbsWg7T
# yquD1rY0wEDrj6REXNkw9+IofYEqyTEyuzGMwKiYUturv65ateDYH2/QkmVBo48k
# H3Tma8uKCDHlQB5H8T1lNELvXEsxH3DJzGu7swjm+MyOGqX7Uv49PvYxD6NtSy3z
# +7eMCk48pvbGr06H7u1pLaAgvymGtFUlCH93tC1Rqsitp3Op8oYMRIymhh/sclKJ
# ZfxAKmWPvyBSGu2oFeSIOd/hOAKG68eP03AUMYIEDTCCBAkCAQEwgZMwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIeo6ykbjlvfEkAAQAAAh4wDQYJ
# YIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkq
# hkiG9w0BCQQxIgQgUZlx/e7uXmghXoQgQ8nL/1PSNlCp9GgHkV0dpfI1zjowgfoG
# CyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCAvgV1q8/YHjIDPAb5/G6sR44R1ydvR
# AYsyEyMNAfbzgjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# AhMzAAACHqOspG45b3xJAAEAAAIeMCIEIKpoWTM5o1sZgkQUp6jXWTuVCHTYE+rU
# LK84mBMEuXImMA0GCSqGSIb3DQEBCwUABIICAC7XLUOkXqvX70r/jUE+AnrSB7TR
# DahAUYyIeJinOFx2Kat8+wT3PEQtbc5+1O/EXJO/xqOjeHn8PbdZonI1pRIaFjr4
# 9XfpEi2DcSUziRaAODyvge4Zg4Z46nuJ8cgzGYCxofzdwbLU+wCt8fl3Pr89udHi
# i0IsW33Ewn1A0sXXZvUWzEbEDlCxYc0PCOH7tHq0l8gVtObEQY+0ObFzqy5OCnLR
# C2YmY7CviN2g0BljZpZqH5vOU0ncIbzwxfWnanSgeYqNYW9Gl9Ws0GMn3v4B6Cyi
# hSwWVqt0kIQ3aWdxCEYEWcDdYf6ipSAoZTjTYHxbE5RIr2kzsaPqtoOYMfUo+VJZ
# 2kh+qx0NTJfTkH3uqoZDo70Xw/3mg/wxbwjlMUEN24E/KLtIYLuZ0kTVSjK1iLwi
# U5EsSFjGNfmQVVC64WyTiHUGVkY818pZ/W4yIhOmjZ4FfsVGsp/xr/UVoZokEXff
# GDHRiBN/yFvWq6//KH+tr2DAgcpp7ec4mqO1mzsX7O+Ec2omJH1VTvIIYn3rxPcT
# krbSKKLjwE6AQx7O5tuLsJsTKScsqQJ0XqyivDnu1RN1QlLaiCicnDfQslp7Awuq
# 2B6z0uIYhbzse9IYQiU323HqTFmehZHUvewICKhDi4LddYGDSEr9wK1vvKQg6R5G
# /Sh+e7Gr1nUZ2Zhu
# SIG # End signature block
