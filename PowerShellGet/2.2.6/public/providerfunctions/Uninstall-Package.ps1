function Uninstall-Package
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )

    Write-Debug -Message ($LocalizedData.ProviderApiDebugMessage -f ('Uninstall-Package'))

    Write-Debug -Message ($LocalizedData.FastPackageReference -f $fastPackageReference)

    # take the fastPackageReference and get the package object again.
    $parts = $fastPackageReference -Split '[|]'
    $Force = $false

    $options = $request.Options
    if($options)
    {
        foreach( $o in $options.Keys )
        {
            Write-Debug -Message ("OPTION: {0} => {1}" -f ($o, $request.Options[$o]) )
        }
    }

    if($parts.Length -eq 5)
    {
        $providerName = $parts[0]
        $packageName = $parts[1]
        $version = $parts[2]
        $sourceLocation= $parts[3]
        $artifactType = $parts[4]

        if($request.IsCanceled)
        {
            return
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

        if($artifactType -eq $script:PSArtifactTypeModule)
        {
            $moduleName = $packageName
            $InstalledModuleInfo = $script:PSGetInstalledModules["$($moduleName)$($version)"]

            if(-not $InstalledModuleInfo)
            {
                $message = $LocalizedData.ModuleUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet -f $moduleName

                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "ModuleUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument

                return
            }

            $moduleBase = $InstalledModuleInfo.PSGetItemInfo.InstalledLocation

            if(-not (Test-RunningAsElevated) -and $moduleBase.StartsWith($script:programFilesModulesPath, [System.StringComparison]::OrdinalIgnoreCase))
            {
                $message = $LocalizedData.AdminPrivilegesRequiredForUninstall -f ($moduleName, $moduleBase)

                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "AdminPrivilegesRequiredForUninstall" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return
            }

            $dependentModuleScript = {
                                param ([string] $moduleName)
                                Microsoft.PowerShell.Core\Get-Module -ListAvailable |
                                Microsoft.PowerShell.Core\Where-Object {
                                    ($moduleName -ne $_.Name) -and (
                                    ($_.RequiredModules -and $_.RequiredModules.Name -contains $moduleName) -or
                                    ($_.NestedModules -and $_.NestedModules.Name -contains $moduleName))
                                }
                            }
            $dependentModulesJob =  Microsoft.PowerShell.Core\Start-Job -ScriptBlock $dependentModuleScript -ArgumentList $moduleName
            Microsoft.PowerShell.Core\Wait-Job -job $dependentModulesJob
            $dependentModules = Microsoft.PowerShell.Core\Receive-Job -job $dependentModulesJob -ErrorAction Ignore

            if(-not $Force -and $dependentModules)
            {
                $message = $LocalizedData.UnableToUninstallAsOtherModulesNeedThisModule -f ($moduleName, $version, $moduleBase, $(($dependentModules.Name | Select-Object -Unique -ErrorAction Ignore) -join ','), $moduleName)

                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "UnableToUninstallAsOtherModulesNeedThisModule" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return
            }

            $moduleInUse = Test-ModuleInUse -ModuleBasePath $moduleBase `
                                            -ModuleName $InstalledModuleInfo.PSGetItemInfo.Name`
                                            -ModuleVersion $InstalledModuleInfo.PSGetItemInfo.Version `
                                            -Verbose:$VerbosePreference `
                                            -WarningAction $WarningPreference `
                                            -ErrorAction $ErrorActionPreference `
                                            -Debug:$DebugPreference

            if($moduleInUse)
            {
                $message = $LocalizedData.ModuleIsInUse -f ($moduleName)

                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "ModuleIsInUse" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation

                return
            }

            $ModuleBaseFolderToBeRemoved = $moduleBase

            # With SxS version support, more than one version of the module can be installed.
            # - Remove the parent directory of the module version base when only one version is installed
            # - Don't remove the modulebase when it was installed before SxS version support and
            #   other versions are installed under the module base folder
            #
            if(Test-ModuleSxSVersionSupport)
            {
                $ModuleBaseWithoutVersion = $moduleBase
                $IsModuleInstalledAsSxSVersion = $false

                if($moduleBase.EndsWith("$version", [System.StringComparison]::OrdinalIgnoreCase))
                {
                    $IsModuleInstalledAsSxSVersion = $true
                    $ModuleBaseWithoutVersion = Microsoft.PowerShell.Management\Split-Path -Path $moduleBase -Parent
                }

                $InstalledVersionsWithSameModuleBase = @()
                Get-Module -Name $moduleName -ListAvailable |
                    Microsoft.PowerShell.Core\ForEach-Object {
                        if($_.ModuleBase.StartsWith($ModuleBaseWithoutVersion, [System.StringComparison]::OrdinalIgnoreCase))
                        {
                            $InstalledVersionsWithSameModuleBase += $_.ModuleBase
                        }
                    }

                # Remove ..\ModuleName directory when only one module is installed with the same ..\ModuleName path
                # like ..\ModuleName\1.0 or ..\ModuleName
                if($InstalledVersionsWithSameModuleBase.Count -eq 1)
                {
                    $ModuleBaseFolderToBeRemoved = $ModuleBaseWithoutVersion
                }
                elseif($ModuleBaseWithoutVersion -eq $moduleBase)
                {
                    # There are version specific folders under the same module base dir
                    # Throw an error saying uninstall other versions then uninstall this current version
                    $message = $LocalizedData.UnableToUninstallModuleVersion -f ($moduleName, $version, $moduleBase)

                    ThrowError -ExceptionName "System.InvalidOperationException" `
                               -ExceptionMessage $message `
                               -ErrorId "UnableToUninstallModuleVersion" `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidOperation

                    return
                }
                # Otherwise specified version folder will be removed as current module base is assigned to $ModuleBaseFolderToBeRemoved
            }

            Microsoft.PowerShell.Management\Remove-Item -Path $ModuleBaseFolderToBeRemoved `
                                                        -Force -Recurse `
                                                        -ErrorAction SilentlyContinue `
                                                        -WarningAction SilentlyContinue `
                                                        -Confirm:$false -WhatIf:$false

            $message = $LocalizedData.ModuleUninstallationSucceeded -f $moduleName, $moduleBase
            Write-Verbose  $message

            Write-Output -InputObject $InstalledModuleInfo.SoftwareIdentity
        }
        elseif($artifactType -eq $script:PSArtifactTypeScript)
        {
            $scriptName = $packageName
            $InstalledScriptInfo = $script:PSGetInstalledScripts["$($scriptName)$($version)"]

            if(-not $InstalledScriptInfo)
            {
                $message = $LocalizedData.ScriptUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet -f $scriptName
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "ScriptUninstallationNotPossibleAsItIsNotInstalledUsingPowerShellGet" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument

                return
            }

            $scriptBase = $InstalledScriptInfo.PSGetItemInfo.InstalledLocation
            $installedScriptInfoPath = $script:MyDocumentsInstalledScriptInfosPath

            if($scriptBase.StartsWith($script:ProgramFilesScriptsPath, [System.StringComparison]::OrdinalIgnoreCase))
            {
                if(-not (Test-RunningAsElevated))
                {
                    $message = $LocalizedData.AdminPrivilegesRequiredForScriptUninstall -f ($scriptName, $scriptBase)

                    ThrowError -ExceptionName "System.InvalidOperationException" `
                               -ExceptionMessage $message `
                               -ErrorId "AdminPrivilegesRequiredForUninstall" `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidOperation

                    return
                }

                $installedScriptInfoPath = $script:ProgramFilesInstalledScriptInfosPath
            }

            # Check if there are any dependent scripts
            $dependentScriptDetails = $script:PSGetInstalledScripts.Values |
                                          Microsoft.PowerShell.Core\Where-Object {
                                              $_.PSGetItemInfo.Dependencies -contains $scriptName
                                          }

            $dependentScriptNames = $dependentScriptDetails |
                                        Microsoft.PowerShell.Core\ForEach-Object { $_.PSGetItemInfo.Name }

            if(-not $Force -and $dependentScriptNames)
            {
                $message = $LocalizedData.UnableToUninstallAsOtherScriptsNeedThisScript -f
                               ($scriptName,
                                $version,
                                $scriptBase,
                                $(($dependentScriptNames | Select-Object -Unique -ErrorAction Ignore) -join ','),
                                $scriptName)

                ThrowError -ExceptionName 'System.InvalidOperationException' `
                           -ExceptionMessage $message `
                           -ErrorId 'UnableToUninstallAsOtherScriptsNeedThisScript' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation
                return
            }

            $scriptFilePath = Microsoft.PowerShell.Management\Join-Path -Path $scriptBase `
                                                                        -ChildPath "$($scriptName).ps1"

            $installedScriptInfoFilePath = Microsoft.PowerShell.Management\Join-Path -Path $installedScriptInfoPath `
                                                                                      -ChildPath "$($scriptName)_$($script:InstalledScriptInfoFileName)"

            # Remove the script file and it's corresponding InstalledScriptInfo.xml
            if(Microsoft.PowerShell.Management\Test-Path -Path $scriptFilePath -PathType Leaf)
            {
                Microsoft.PowerShell.Management\Remove-Item -Path $scriptFilePath `
                                                            -Force `
                                                            -ErrorAction SilentlyContinue `
                                                            -WarningAction SilentlyContinue `
                                                            -Confirm:$false -WhatIf:$false
            }

            if(Microsoft.PowerShell.Management\Test-Path -Path $installedScriptInfoFilePath -PathType Leaf)
            {
                Microsoft.PowerShell.Management\Remove-Item -Path $installedScriptInfoFilePath `
                                                            -Force `
                                                            -ErrorAction SilentlyContinue `
                                                            -WarningAction SilentlyContinue `
                                                            -Confirm:$false -WhatIf:$false
            }

            $message = $LocalizedData.ScriptUninstallationSucceeded -f $scriptName, $scriptBase
            Write-Verbose $message

            Write-Output -InputObject $InstalledScriptInfo.SoftwareIdentity
        }
    }
}
# SIG # Begin signature block
# MIInOQYJKoZIhvcNAQcCoIInKjCCJyYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCSsW5Lxq6YWVxF
# 9JYF0W38bU8wpmV7TVkncq3XIE+tHaCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIEyzKSJTE9oZhwo4SZmGAv9kOGLR
# gLCjpalJ9Aqf8R8uMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAgAFedxr5huZLen6XwMAOQHIdJYWbafVCyKAHDP2pVx6lQZUzVTwwXt/oQIty
# Ce43OJ5eFm/ZhUoWh6t8NiTVDfzfdNCG51lZBUHzHM08WQ2S4C2cOqGLBK+lFAa3
# ZYjrSbEKWjpMxRcX5PBzHBzpDxnKFimNrH4BTV2+6krnwS8yhtTev9QqOzaUd6c0
# 3JJBu5qrIN/ZxNti8fEamSU5sDX/9tbvKxPgV9sHTOVziEhDrHuUHjTlzbKbUDvB
# +o56RrACvKNjm6qN2W1FcRf2/g00x5VhtLufjrTg3/5dwdTbq+J/18fLIHB+7D35
# tVU74JoTO/Vy9bMPAmMWWEDl+KGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34G
# CSqGSIb3DQEHAqCCF28wghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCDOJXnNKOpzRXr8jhgI76os3ktMpkEhmk/k0UGu1zsxVgIGavNMAR3nGBMy
# MDI2MTExMDIyMDU1Ny42OTZaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTQwMC0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHs
# MIIHIDCCBQigAwIBAgITMwAAAijwpYfX88geQAABAAACKDANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMDZa
# Fw0yNzA1MTcxOTQwMDZaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTQwMC0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCujvbk/sqcCSReZaJfCuf1NwRcc7XknhE6wkLofkNj1mxE
# Ag35qy2xcFjgjartVvA09W8QHcpyMqVSXOTxNHJsmk0qP2CDLvUAulWg7aS5oBOR
# pEX1oz3n0R2nPqeH0IHK1zJxjxaHW21AbuZ0Z+wM3WYNzkBlcHmVe03ZG7rlk28h
# 72r5P5ME8FGpFmYW5Hl7psKbgLEfrYAitpttsb+sZsBUI+hMKl4uLJYotKyZv1ew
# OIinBfRU8QosivjofaBezUf9NdV+iGrWh321WnSsK3A/Jl6GLtbSWXcJWULgbxuq
# nobPK+YlB3174TMWTgX4YWjG7o0Otz/pjHNCKBbB788dynhLdGY6B08E9+4SGrRp
# sty4iJHOydHCA5M4i5yYRwsdut+gmvxIpT8yNXJcjJCg0vO8mv/nFY9Wytv2qmCt
# CFFivGUWqU20/sUeRooQZGiQOJQn095Cj3isIsvRP8KU7hN/EDI8HVsb/NPzMFLv
# RznrRnj0TOnDiOTUcnYwmk+XfoS1owskcCCCwHnbC00D58z83y7K5ZJB745hcn4C
# E2nR3e6RGsr42y5qtt6Mdz/s7MTnDS2UmVHWX1X/HZe3UlX8gj/t63L50xIPqkRC
# BEdM1ADNUaSfo9OQiKb/bj1diZCGTfEDUBBLop1mhkwIF82faplV2busZ+U4kQID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFKrJpYz48tzouvVkBVthASFpQ93DMB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQCQ6NfLmrRahgVtgWg383GaS07fHyod6bhcUONt
# 2tet+6BaNuH0r7ABkVHheOpxBdrUrOEYVEaIii9dK3cuZLNmp1iUAx/VbmOZYl7x
# z+tNrjCWqrg1jQmq0oRB8iE4QJpwNhGP67oY5huYIU0D4lhDoahqfgKJn/0Bk+9U
# KDPw5XlUYmreFmJlj9YQzcPPep8MxBXxh/Y5I7vQeRaW5SjtiLQOLRk3ggvraDs5
# Sf49MJV6/BwxXC2rvUfEFX6SUDooqKIE9NgVIRq0RZu7Ot0i0Is+HvPP0hB6KwOx
# Mg1SWKOfTtFpWpdo8MJvgKCHkPpXEzgprP+pyIHuO7gVRlSTsbYBFLh2yId/itM4
# uYL0R+2SSBBTpSSRthrGuEmElI5BCHMxzMg/oqHSPwZAIAkM2C4xxi0St7qMuA+m
# +ZzFYkfoF41QoSJn+HjqhqWYQ0m/SO9/KnJRJJUwMd5TiMnjZ+E/DJiUry5udiWy
# Qpvfj2hQFI0djhahoAXDazeEciLF2uEnTur9UfjcwOun/oMY+ULftnOi2jKLMrre
# V097akzz/JxpnDgYJU/tgU7fQflg7IqiL9+0276+joQHo21mVeY5YD8Kh/kUaY6J
# m/OTM88G7evTz/qnRumxovTjMStvpbAHNRhmSTdIPTV32CyuxDKS/V5a5iwA+f9V
# iBo+wjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# A1UECxMeblNoaWVsZCBUU1MgRVNOOkE0MDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQB1rbmF
# kzS7qAK1Oav08AUnhbNIUqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3KdTAiGA8yMDI2MTExMDE2NTMwOVoY
# DzIwMjYxMTExMTY1MzA5WjB2MDwGCisGAQQBhFkKBAExLjAsMAoCBQDuncp1AgEA
# MAkCAQACARcCAf8wBwIBAAICEmkwCgIFAO6fG/UCAQAwNgYKKwYBBAGEWQoEAjEo
# MCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG
# 9w0BAQsFAAOCAQEAKXaJZwqvlfDEvlkGE3oiqxhec9pu+Y1s0DzjrXetxn0otvmD
# gRlN0HKs6PFuAbSCGjna4sb/BZd+QYxsu/DzstF3Z9bfiot21sRM2+J2GbE3Jc1O
# l8gi4ZOR4k9GFGzxfoYBj0fD7UsD9xupPiPiafaz2GYxuiEdkH+CrdduUGv0XxJK
# iqdlUFbhYv5zsS3PT2qewbjTX/U9HMUz/msfcURAsKzQ+j43QtDN516Dlkv04utL
# mh1c8N4OyUAqtVhljouZU4Aw7JyQEJpJ8Y3e/6KRS8gH1VN0FQ4z5l86LDQTgTrR
# k+lcdr7Pm6NDEHP367GMyh8d98pnzNEDbpjI6TGCBA0wggQJAgEBMIGTMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACKPClh9fzyB5AAAEAAAIoMA0G
# CWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJ
# KoZIhvcNAQkEMSIEIJZWhR+Bg8kAZzjJ+rXJwsX5D+wIwljVmJwLo6luHDXwMIH6
# BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgVbGKRlFgY1/igRVkrV5Pjkf7cZDf
# +rFXvlXC4G36ItcwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MAITMwAAAijwpYfX88geQAABAAACKDAiBCB1+e5R8U2Jsr/X/t9V5TW9VX41Tnb1
# wWm+Dhc2MV7+ETANBgkqhkiG9w0BAQsFAASCAgCOC4d/ZQUnbR4aajn/Q+gq4GQf
# 4oWjtqverIOULcYK21XJ0Nm/6PDHUdKYEUvIMLF+EwoZTsJqAtJ6M4AjKn3HIjcD
# snjpWUa8AnVlVoVJN6HnlRdc/uWDWjzBiecscbbQObxzQkd8oU137fK1zQMzXhbS
# DkuXZP2QD0tjNbqUW8B+SmYr2JnBFYJd0cgX5Uo6JQixwz/1p+A2AmLsXWDobKZ9
# EsuJYJmEdWSpQ3WGMDegbekWbHD4Y6plvtR/Qc80kV97xtUKHjvpdDBsWJ4JqwQX
# mgC2xqsdeiQChxFZWPF3D3TflsesqrBOO4nrR3Sj/GlQbHxRRpkevCE0z33Coyo9
# Uf4i00XNfc56usa196/77E54BraqyBTzN2l8oq9hzYyVFYSwnabxJF1H8h+R4nDN
# DH/3Phr94l9qagpOv+tSu4L0Cszs/XPuzjp7ZwaxqaRwn1H7doosS5fh2VeR+kOo
# XP0yyQR7OgPC2PH9URYaWhTYGSGYgQAQyHEWu0hjctpP/NHo4DZGPryZqTee7iN6
# UDJk77nT7/BAhtapcT/UfAXEj+Wc6XU7VyuvUVcDkCEX9We4kih+SAE3Ry9zsDw2
# +brSM6glQtglsFvudlONsaSoUhJHdRxhKXLbg+9tcgB6klRqhNw8edbhB69jkdJs
# DW6Inx8XuR/qjG3VSQ==
# SIG # End signature block
