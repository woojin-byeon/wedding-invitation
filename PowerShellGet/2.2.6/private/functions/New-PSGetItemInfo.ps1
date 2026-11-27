function New-PSGetItemInfo
{
    param
    (
        [Parameter(Mandatory=$true)]
        $SoftwareIdentity,

        [Parameter()]
        $PackageManagementProviderName,

        [Parameter()]
        [string]
        $SourceLocation,

        [Parameter(Mandatory=$true)]
        [string]
        $Type,

        [Parameter()]
        [string]
        $InstalledLocation,

        [Parameter()]
        [System.DateTime]
        $InstalledDate,

        [Parameter()]
        [System.DateTime]
        $UpdatedDate
    )

    foreach($swid in $SoftwareIdentity)
    {

        if($SourceLocation)
        {
            $sourceName = (Get-SourceName -Location $SourceLocation)
        }
        else
        {
            # First get the source name from the Metadata
            # if not exists, get the source name from $swid.Source
            # otherwise default to $swid.Source
            $sourceName = (Get-First $swid.Metadata["SourceName"])

            if(-not $sourceName)
            {
                $sourceName = (Get-SourceName -Location $swid.Source)
            }

            if(-not $sourceName)
            {
                $sourceName = $swid.Source
            }

            $SourceLocation = Get-SourceLocation -SourceName $sourceName
        }

        $published = (Get-First $swid.Metadata["published"])
        $PublishedDate = New-Object System.DateTime

        $InstalledDateString = (Get-First $swid.Metadata['installeddate'])
        if(-not $InstalledDate -and $InstalledDateString)
        {
            $InstalledDate = New-Object System.DateTime
            if(-not (([System.DateTime]::TryParse($InstalledDateString, [System.Globalization.DateTimeFormatInfo]::InvariantInfo, [System.Globalization.DateTimeStyles]::None, ([ref]$InstalledDate))) -or
                     ([System.DateTime]::TryParse($InstalledDateString, ([ref]$InstalledDate)))))
            {
                $InstalledDate = $null
            }
        }

        $UpdatedDateString = (Get-First $swid.Metadata['updateddate'])
        if(-not $UpdatedDate -and $UpdatedDateString)
        {
            $UpdatedDate = New-Object System.DateTime
            if(-not (([System.DateTime]::TryParse($UpdatedDateString, [System.Globalization.DateTimeFormatInfo]::InvariantInfo, [System.Globalization.DateTimeStyles]::None, ([ref]$UpdatedDate))) -or
                     ([System.DateTime]::TryParse($UpdatedDateString, ([ref]$UpdatedDate)))))
            {
                $UpdatedDate = $null
            }
        }

        $tags = (Get-First $swid.Metadata["tags"]) -split " "
        $userTags = @()

        $exportedDscResources = @()
        $exportedRoleCapabilities = @()
        $exportedCmdlets = @()
        $exportedFunctions = @()
        $exportedWorkflows = @()
        $exportedCommands = @()

        $exportedRoleCapabilities += (Get-First $swid.Metadata['RoleCapabilities']) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedDscResources += (Get-First $swid.Metadata["DscResources"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedCmdlets += (Get-First $swid.Metadata["Cmdlets"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedFunctions += (Get-First $swid.Metadata["Functions"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedWorkflows += (Get-First $swid.Metadata["Workflows"]) -split " " | Microsoft.PowerShell.Core\Where-Object { $_.Trim() }
        $exportedCommands += $exportedCmdlets + $exportedFunctions + $exportedWorkflows
        $PSGetFormatVersion = $null

        ForEach($tag in $tags)
        {
            if(-not $tag.Trim())
            {
                continue
            }

            $parts = $tag -split "_",2
            if($parts.Count -ne 2)
            {
                $userTags += $tag
                continue
            }

            Switch($parts[0])
            {
                $script:Command            { $exportedCommands += $parts[1]; break }
                $script:DscResource        { $exportedDscResources += $parts[1]; break }
                $script:Cmdlet             { $exportedCmdlets += $parts[1]; break }
                $script:Function           { $exportedFunctions += $parts[1]; break }
                $script:Workflow           { $exportedWorkflows += $parts[1]; break }
                $script:RoleCapability     { $exportedRoleCapabilities += $parts[1]; break }
                $script:PSGetFormatVersion { $PSGetFormatVersion = $parts[1]; break }
                $script:Includes           { break }
                Default                    { $userTags += $tag; break }
            }
        }

        $ArtifactDependencies = @()
        Foreach ($dependencyString in $swid.Dependencies)
        {
            [Uri]$packageId = $null
            if([Uri]::TryCreate($dependencyString, [System.UriKind]::Absolute, ([ref]$packageId)))
            {
                $segments = $packageId.Segments
                $Version = $null
                $DependencyName = $null
                if ($segments)
                {
                    $DependencyName = [Uri]::UnescapeDataString($segments[0].Trim('/', '\'))
                    $Version = if($segments.Count -gt 1){[Uri]::UnescapeDataString($segments[1])}
                }

                $dep = [ordered]@{
                            Name=$DependencyName
                        }

                if($Version)
                {
                    # Required/exact version is represented in NuGet as "[2.0]"
                    if ($Version -match "\[+[0-9.]+\]")
                    {
                        $dep["RequiredVersion"] = $Version.Trim('[', ']')
                    }
                    elseif ($Version -match "\[+[0-9., ]+\]")
                    {
                        # Minimum and Maximum version range is represented in NuGet as "[1.0, 2.0]"
                        $versionRange = $Version.Trim('[', ']') -split ',' | Microsoft.PowerShell.Core\Where-Object {$_}
                        if($versionRange -and $versionRange.count -eq 2)
                        {
                            $dep["MinimumVersion"] = $versionRange[0].Trim()
                            $dep["MaximumVersion"] = $versionRange[1].Trim()
                        }
                    }
                    elseif ($Version -match "\(+[0-9., ]+\]")
                    {
                        # Maximum version is represented in NuGet as "(, 2.0]"
                        $maximumVersion = $Version.Trim('(', ']') -split ',' | Microsoft.PowerShell.Core\Where-Object {$_}

                        if($maximumVersion)
                        {
                            $dep["MaximumVersion"] = $maximumVersion.Trim()
                        }
                    }
                    else
                    {
                        $dep['MinimumVersion'] = $Version
                    }
                }

                $dep["CanonicalId"]=$dependencyString

                $ArtifactDependencies += $dep
            }
        }

        $additionalMetadata =  Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{})
        foreach ( $key in $swid.Metadata.Keys.LocalName)
        {
            Microsoft.PowerShell.Utility\Add-Member -InputObject $additionalMetadata `
                                                    -MemberType NoteProperty `
                                                    -Name $key `
                                                    -Value (Get-First $swid.Metadata[$key])
        }

        if (-not (Get-Member -InputObject $additionalMetadata -Name "IsPrerelease") )
        {
            if ($swid.Version -match '-')
            {
                Microsoft.PowerShell.Utility\Add-Member -InputObject $additionalMetadata `
                                                        -MemberType NoteProperty `
                                                        -Name 'IsPrerelease' `
                                                        -Value $true
            }
            else {
                Microsoft.PowerShell.Utility\Add-Member -InputObject $additionalMetadata `
                                                        -MemberType NoteProperty `
                                                        -Name 'IsPrerelease' `
                                                        -Value $false
            }
        }

        if(Get-Member -InputObject $additionalMetadata -Name 'ItemType')
        {
            $Type = $additionalMetadata.'ItemType'
        }
        elseif($userTags -contains 'PSModule')
        {
            $Type = $script:PSArtifactTypeModule
        }
        elseif($userTags -contains 'PSScript')
        {
            $Type = $script:PSArtifactTypeScript
        }


        $PSGetItemInfo = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
                Name = $swid.Name
                Version = $swid.Version
                Type = $Type
                Description = (Get-First $swid.Metadata["description"])
                Author = (Get-EntityName -SoftwareIdentity $swid -Role "author")
                CompanyName = (Get-EntityName -SoftwareIdentity $swid -Role "owner")
                Copyright = (Get-First $swid.Metadata["copyright"])
                PublishedDate = if([System.DateTime]::TryParse($published, ([ref]$PublishedDate))){$PublishedDate};
                InstalledDate = $InstalledDate;
                UpdatedDate = $UpdatedDate;
                LicenseUri = (Get-UrlFromSwid -SoftwareIdentity $swid -UrlName "license")
                ProjectUri = (Get-UrlFromSwid -SoftwareIdentity $swid -UrlName "project")
                IconUri = (Get-UrlFromSwid -SoftwareIdentity $swid -UrlName "icon")
                Tags = $userTags

                Includes = @{
                                DscResource = $exportedDscResources
                                Command     = $exportedCommands
                                Cmdlet      = $exportedCmdlets
                                Function    = $exportedFunctions
                                Workflow    = $exportedWorkflows
                                RoleCapability = $exportedRoleCapabilities
                            }

                PowerShellGetFormatVersion=[Version]$PSGetFormatVersion

                ReleaseNotes = (Get-First $swid.Metadata["releaseNotes"])

                Dependencies = $ArtifactDependencies

                RepositorySourceLocation = $SourceLocation
                Repository = $sourceName
                PackageManagementProvider = if($PackageManagementProviderName) { $PackageManagementProviderName } else { (Get-First $swid.Metadata["PackageManagementProvider"]) }

				AdditionalMetadata = $additionalMetadata
            })

        if(-not $InstalledLocation)
        {
            $InstalledLocation = (Get-First $swid.Metadata[$script:InstalledLocation])
        }

        if($InstalledLocation)
        {
            Microsoft.PowerShell.Utility\Add-Member -InputObject $PSGetItemInfo -MemberType NoteProperty -Name $script:InstalledLocation -Value $InstalledLocation
        }

        $PSGetItemInfo.PSTypeNames.Insert(0, "Microsoft.PowerShell.Commands.PSRepositoryItemInfo")
        $PSGetItemInfo
    }
}
# SIG # Begin signature block
# MIInNgYJKoZIhvcNAQcCoIInJzCCJyMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAeTeYUsDkIy5cs
# 9arfMwJsn0N+IINqS+8VdSmsgr69QaCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEID8JRmE2q7SVp1iN5tQMveR8ozsF
# FdgapWc86J9EsMt5MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEAtzRzgRugQ+/nLEdUOmTdTl0F2+eyBiYKfxLMjMcyHQ5TM7iQbJ+X5y4qYy2+
# 9QFcNj0M+KXWtVrMlYzjJyMQ9sm9Xg0lQ4WhwyxjzylCAwkMNnIEXvct8RC+zPuE
# KbjQh5eX5vYcqEo1kobkykpPgOv1nMUWr9StVcf6AX0ABTq+WXQ8329uNgwTEkH3
# yWb+x12YB3tlQ7oRRMVkADMpARq9hSfYEVoQaV30QKeu9bkf+ELzv86DtZwR6NiZ
# sWG7AUaxmgQhBNQl1zAdm8MxFyWk6V9/dD+pyxyw6Bz9/4uSgmrCEMrPq1DDrGxW
# h3D0E3iTC5bqifnxm5RWaL3OLqGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sG
# CSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCC42ulJQ9E34jrwWqw0hluu33er/WVR9SgmvIvZWo7FcAIGavNsoiFBGBMy
# MDI2MTExMDIyMDUyMy42NzRaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHp
# MIIHIDCCBQigAwIBAgITMwAAAiJB0vaq/8i1/wABAAACIjANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTM5NTZa
# Fw0yNzA1MTcxOTM5NTZaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQC1ueKJukIuUsAAJo/AY5DZRqH7bhgv7CWGNlEdbRGoITrd
# E6Wsn57NaNu1BTdjBbFcv7Rfixte0x+HRvXSqsD+WeSX/6/y9wE0Mz+xRPTGIY20
# K7aQDa68OyzVyUeUCypyZC/gW/3ytO/ZOnU9H2ri77kJP8ABrqyy1UxX/OseEgvH
# sj8yikWT0ARtrjWbXMHFzSOo5hQcfUmMXKqWWz6+N0+UynhGy1n+doW4WZgpH8Y5
# W7hpSokWj1M/Lu4wi3o6Dz9vVWukcgUFGjLAl4YZpOhah7HuiC/alXImMQf8C3A8
# q/6/1hFoeIZB4UGkywxB/OSTOSsL6+39pDqzM7CgOpf4V799kN94yM9uXJI5T/Si
# A5MdIZIhEW0+bh85RqDh5YW3/oav54RPxw5OPlH64QV6KJkl0FIElMVoLNo8UWRQ
# cMD179x7WASjC6LsaNZ7yK0qcESIsL1wiQmdfQBxcqrFCpIQfnmQFkOp9IyXUWqz
# a8tmpz8E6aXg9b1eiAT3PVTgrOlPi/hYZCfPxX/6jGtyPjy1CiwOmJamohmSU//C
# OAenfRT2G2HMRUpCX1zs+AmDmdQM1XRab4YSALLAlDzGCsgI77nnuJjoXAliJmv7
# NfrvWAcA5KqCUOWQ6kSPt5r28MfKXWJJpSXtFeS/MkDzJy/iJRVyHcFy/B+MtwID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFFkHwGoDJ5ZbEEiu8KstiusqaozQMB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQBiAM+nqrpwG29txSXv42o+CsTe2C4boaRfFju9
# JaWkLTHwq7pknNONL3n+UG3x/B083EKXiFYrAmul7BTHCGXU63/xRsZ2wj3ZmR0A
# 4d9nf9saCJVm4juPVFBai/oktOOYH2j+1+zM70woN5ongB/pvy7X8AfY6JB4XPvb
# 80Qz7fY5eddbnwjzg1sZhUPFbbcweWeACINrzqFK62mMeXKmhtufMraoogJeJXfW
# Y3x4/pbubgENT3+pXT65203CPF9kfdKE7GKAIRYy3xkBTDvFd8dufjOpCn38nK6q
# MlVtnBjDhWQG0PM3E/oxBs5UBrI6pBYkmIHtbjifDquHT+ThaVV7xHc6InoSc3aN
# zX49JHUgQmuvDdMjLkbYXeA0/1q5IxSg2U+ycZBOvAi3udZPKhA5VzODjf/ucu/v
# FtXrYcRkmGKN3jujaK3/yMZi2Ju5NEL3ISWorwp7RjeZg+JMIK0fosuVj+YCm5r6
# 4LH/D9QJDAj+XfZaNeFdv90K5A0QRRGP/poB9yTIVjEXj/uJzp8L4Dd44sAquqDO
# iHdkLgxfK8nPqpCSWPZ9G+RCPm85o9cAfxENtrSuOwcpyKzxsRCYCL+PK4+98ori
# t9EVJ/LLoCeG+jLlj0KaD4Qy6sZe4rWMr1brQLosTBZNwFnXxNjInCWBd0i7is1y
# TS/4qTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# A1UECxMeblNoaWVsZCBUU1MgRVNOOjg5MDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQC7ycXV
# Zx3bsDpJkr7VucgpksozuKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3rHzAiGA8yMDI2MTExMDE5MTIzMVoY
# DzIwMjYxMTExMTkxMjMxWjBzMDkGCisGAQQBhFkKBAExKzApMAoCBQDunesfAgEA
# MAYCAQACASIwBwIBAAICEdkwCgIFAO6fPJ8CAQAwNgYKKwYBBAGEWQoEAjEoMCYw
# DAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0B
# AQsFAAOCAQEAGj3g0qyRmFpj4xjOZaKhqhHztJx0L7RwLI/v3ZiO/3LId7jKUXUm
# 5QxnKSNKeNSN2UXaKBFZMaSL6goF6szYe4EMx1SEd+9RVRipiDekCS7KMe4ekFRM
# fb5RYvqA/FxLjgE11DODlqbUh4olrUK+RKZ1ZGN+ft+3DQ19yOvbKVwk0vr4pui4
# eckeDcWuHtOm5xAf/s9iBmuit2dmwwCPy75IzEb8QFavqaiSkRTDKJLxlRsjAm6D
# vJBsC5Bw32Xb7VHZk2H9HQTQqODyZvpy8+pdcQNvymJg0rFjyLSRrV+z634j5IyY
# LXjS8K8+UBUpG7yt8UJBuODs5uNt11BkkjGCBA0wggQJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACIkHS9qr/yLX/AAEAAAIiMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIFmixIPJS661qees9khoHYNHkG9tVcnMJZXUs2BK6IcTMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgBWBdAQoE58aCM2ySYM6ZtwQg6ccY3AD5
# BxG58NHkCRMwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAiJB0vaq/8i1/wABAAACIjAiBCAEQdaNUyuzQzLqNh2eQn8wNTeTXAEBIX4b
# W1Bx3wSc+jANBgkqhkiG9w0BAQsFAASCAgA+51HjTfRe9fDcNTfTQr/GWOBH+bmU
# Nojsl/LbNaRUJk6910H4DDq0Ee3rrokdvYpp9fv1A/xw+ES1YqdyugfKfeQqSXQa
# CNmVcguoyJ1CxtHBnFrEvlvuJR7MSxDibIE5beHbRp+yXmz192mQwZM0yTo+7cQv
# p/SimQvkvVrdEr6fgoubJToxvRgrCPojUbeyx93aztFPXlimewbp2ueDEu+wGPxk
# RbKum9uOR+OIVqw4N45cJXKHm4+Mk++ugVUQHP1IjVyEj1I6OqFwB+9Lh5iPTkFU
# ZZQ75NjFG9wsYfrUE867QUT4gTq3l1U8yJbBAct+KSCNN1lgRR+UrA/8TAvD75M8
# h+FiC6+FS5/xflWAC3LCR7HXV9WxVI7eQ9YmSPGWblnjsvPoLV1jVF3GIroaQlHv
# PVaJHxrfk3qNKSO7kx74YR/vqFHhXd2vgkZfHzL1S1dXEUFtJ/nt9n1+2X0qTFop
# 9KEuc9hRU+o6E8hwXwvm4p25tACkAQ0awwV5xqTKFggoWSNYJb/n89LZka37e1Qh
# 26/U0VKLpscdqKoPH0IO02a6jvUUR2iQF24rtbQzsDGba76DdYJ8iwdU2qTCTUqG
# GHWgGHLYppLkmIPMm1e1qby9AuT67HRooYVxE87tnGL9utGHBITyzNEfj9onrHlP
# ZKq/DaThGmOeVA==
# SIG # End signature block
