function Update-ModuleManifest
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true,
                   PositionalBinding=$false,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkId=619311')]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [ValidateNotNullOrEmpty()]
        [Object[]]
        $NestedModules,

        [ValidateNotNullOrEmpty()]
        [Guid]
        $Guid,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Author,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $CompanyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Copyright,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RootModule,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $ModuleVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Reflection.ProcessorArchitecture]
        $ProcessorArchitecture,

        [Parameter()]
        [ValidateSet('Desktop','Core')]
        [string[]]
        $CompatiblePSEditions,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $PowerShellVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $ClrVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $DotNetFrameworkVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $PowerShellHostName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Version]
        $PowerShellHostVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Object[]]
        $RequiredModules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $TypesToProcess,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $FormatsToProcess,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ScriptsToProcess,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $RequiredAssemblies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $FileList,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [object[]]
        $ModuleList,

        [Parameter()]
        [string[]]
        $FunctionsToExport,

        [Parameter()]
        [string[]]
        $AliasesToExport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $VariablesToExport,

        [Parameter()]
        [string[]]
        $CmdletsToExport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $DscResourcesToExport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $PrivateData,

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
        [string]
        $Prerelease,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $HelpInfoUri,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $DefaultCommandPrefix,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ExternalModuleDependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $PackageManagementProviders,

        [Parameter()]
        [switch]
        $RequireLicenseAcceptance


    )

    if(-not (Microsoft.PowerShell.Management\Test-Path -Path $Path -PathType Leaf))
    {
        $message = $LocalizedData.UpdateModuleManifestPathCannotFound -f ($Path)
        ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $message `
                   -ErrorId "InvalidModuleManifestFilePath" `
                   -ExceptionObject $Path `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
    }

    $ModuleManifestHashTable = $null

    try
    {
        $ModuleManifestHashTable = Get-ManifestHashTable -Path $Path -CallerPSCmdlet $PSCmdlet
    }
    catch
    {
        $message = $LocalizedData.TestModuleManifestFail -f ($_.Exception.Message)
        ThrowError -ExceptionName "System.ArgumentException" `
                    -ExceptionMessage $message `
                    -ErrorId "InvalidModuleManifestFile" `
                    -ExceptionObject $Path `
                    -CallerPSCmdlet $PSCmdlet `
                    -ErrorCategory InvalidArgument
        return
    }

    #Get the original module manifest and migrate all the fields to the new module manifest, including the specified parameter values
    $moduleInfo = $null

    try
    {
        $moduleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $Path -ErrorAction Stop
    }
    catch
    {
        # Throw an error only if Test-ModuleManifest did not return the PSModuleInfo object.
        # This enables the users to use Update-ModuleManifest cmdlet to update the metadata.
        if(-not $moduleInfo)
        {
            $message = $LocalizedData.TestModuleManifestFail -f ($_.Exception.Message)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "InvalidModuleManifestFile" `
                       -ExceptionObject $Path `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
            return
        }
    }

    #Params to pass to New-ModuleManifest module
    $params = @{}

    #NestedModules is read-only property
    if($NestedModules)
    {
        $params.Add("NestedModules",$NestedModules)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("NestedModules"))
    {
        $params.Add("NestedModules",$ModuleManifestHashtable.NestedModules)
    }

    #Guid is read-only property
    if($Guid)
    {
        $params.Add("Guid",$Guid)
    }
    elseif($moduleInfo.Guid)
    {
        $params.Add("Guid",$moduleInfo.Guid)
    }

    if($Author)
    {
        $params.Add("Author",$Author)
    }
    elseif($moduleInfo.Author)
    {
        $params.Add("Author",$moduleInfo.Author)
    }

    if($CompanyName)
    {
        $params.Add("CompanyName",$CompanyName)
    }
    elseif($moduleInfo.CompanyName)
    {
        $params.Add("CompanyName",$moduleInfo.CompanyName)
    } 
    else  
    {
        #Creating a unique disposable company name to later be replaced by ''
        #Work-around to deal with New-ModuleManifest changing '' to 'Unknown'
        $params.Add("CompanyName", '__UPDATEDCOMPANYNAMETOBEREPLACEDINFUNCTION__')
    }

    if($Copyright)
    {
        $params.Add("CopyRight",$Copyright)
    }
    elseif($moduleInfo.Copyright)
    {
        $params.Add("Copyright",$moduleInfo.Copyright)
    }

    if($RootModule)
    {
        $params.Add("RootModule",$RootModule)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("RootModule") -and $moduleInfo.RootModule)
    {
        $params.Add("RootModule",$ModuleManifestHashTable.RootModule)
    }

    if($ModuleVersion)
    {
        $params.Add("ModuleVersion",$ModuleVersion)
    }
    elseif($moduleInfo.Version)
    {
        $params.Add("ModuleVersion",$moduleInfo.Version)
    }

    if($Description)
    {
        $params.Add("Description",$Description)
    }
    elseif($moduleInfo.Description)
    {
        $params.Add("Description",$moduleInfo.Description)
    }

    if($ProcessorArchitecture)
    {
        $params.Add("ProcessorArchitecture",$ProcessorArchitecture)
    }
    #Check if ProcessorArchitecture has a value and is not 'None' on lower version PS
    elseif($moduleInfo.ProcessorArchitecture -and $moduleInfo.ProcessorArchitecture -ne 'None')
    {
        $params.Add("ProcessorArchitecture",$moduleInfo.ProcessorArchitecture)
    }

    if($PowerShellVersion)
    {
        $params.Add("PowerShellVersion",$PowerShellVersion)
    }
    elseif($moduleinfo.PowerShellVersion)
    {
        $params.Add("PowerShellVersion",$moduleinfo.PowerShellVersion)
    }

    if($ClrVersion)
    {
        $params.Add("ClrVersion",$ClrVersion)
    }
    elseif($moduleInfo.ClrVersion)
    {
        $params.Add("ClrVersion",$moduleInfo.ClrVersion)
    }

    if($DotNetFrameworkVersion)
    {
        $params.Add("DotNetFrameworkVersion",$DotNetFrameworkVersion)
    }
    elseif($moduleInfo.DotNetFrameworkVersion)
    {
        $params.Add("DotNetFrameworkVersion",$moduleInfo.DotNetFrameworkVersion)
    }

    if($PowerShellHostName)
    {
        $params.Add("PowerShellHostName",$PowerShellHostName)
    }
    elseif($moduleInfo.PowerShellHostName)
    {
        $params.Add("PowerShellHostName",$moduleInfo.PowerShellHostName)
    }

    if($PowerShellHostVersion)
    {
        $params.Add("PowerShellHostVersion",$PowerShellHostVersion)
    }
    elseif($moduleInfo.PowerShellHostVersion)
    {
        $params.Add("PowerShellHostVersion",$moduleInfo.PowerShellHostVersion)
    }

    if($RequiredModules)
    {
        $params.Add("RequiredModules",$RequiredModules)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("RequiredModules") -and $moduleInfo.RequiredModules)
    {
        $params.Add("RequiredModules",$ModuleManifestHashtable.RequiredModules)
    }

    if($TypesToProcess)
    {
        $params.Add("TypesToProcess",$TypesToProcess)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("TypesToProcess") -and $moduleInfo.ExportedTypeFiles)
    {
        $params.Add("TypesToProcess",$ModuleManifestHashTable.TypesToProcess)
    }

    if($FormatsToProcess)
    {
        $params.Add("FormatsToProcess",$FormatsToProcess)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FormatsToProcess") -and $moduleInfo.ExportedFormatFiles)
    {
        $params.Add("FormatsToProcess",$ModuleManifestHashTable.FormatsToProcess)
    }

    if($ScriptsToProcess)
    {
        $params.Add("ScriptsToProcess",$ScriptstoProcess)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("ScriptsToProcess") -and $moduleInfo.Scripts)
    {
        $params.Add("ScriptsToProcess",$ModuleManifestHashTable.ScriptsToProcess)
    }

    if($RequiredAssemblies)
    {
        $params.Add("RequiredAssemblies",$RequiredAssemblies)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("RequiredAssemblies") -and $moduleInfo.RequiredAssemblies)
    {
        $params.Add("RequiredAssemblies",$moduleInfo.RequiredAssemblies)
    }

    if($FileList)
    {
        $params.Add("FileList",$FileList)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FileList") -and $moduleInfo.FileList)
    {
        $params.Add("FileList",$ModuleManifestHashTable.FileList)
    }

    #Make sure every path defined under FileList is within module base
    $moduleBase = $moduleInfo.ModuleBase
    foreach($file in $params["FileList"])
    {
        #If path is not root path, append the module base to it and check if the file exists
        if(-not [System.IO.Path]::IsPathRooted($file))
        {
            $combinedPath = Join-Path $moduleBase -ChildPath $file
        }
        else
        {
            $combinedPath = $file
        }
        if(-not (Microsoft.PowerShell.Management\Test-Path -Type Leaf -LiteralPath $combinedPath))
        {
            $message = $LocalizedData.FilePathInFileListNotWithinModuleBase -f ($file,$moduleBase)
            ThrowError -ExceptionName "System.ArgumentException" `
               -ExceptionMessage $message `
               -ErrorId "FilePathInFileListNotWithinModuleBase" `
               -ExceptionObject $file `
               -CallerPSCmdlet $PSCmdlet `
               -ErrorCategory InvalidArgument

            return
        }
    }

    if($ModuleList)
    {
        $params.Add("ModuleList",$ModuleList)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("ModuleList") -and $moduleInfo.ModuleList)
    {
        $params.Add("ModuleList",$ModuleManifestHashtable.ModuleList)
    }

    if($FunctionsToExport -or $FunctionsToExport -is [array])
    {
        $params.Add("FunctionsToExport",$FunctionsToExport)
    }
    elseif($moduleInfo.ExportedFunctions)
    {
        #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FunctionsToExport") -and $ModuleManifestHashTable['FunctionsToExport'] -eq '*' `
            -and $moduleInfo.ExportedFunctions.Keys.Count -eq 0)
        {
            $params.Add("FunctionsToExport", $ModuleManifestHashTable['FunctionsToExport'])
        }
        elseif($moduleInfo.Prefix)
        {
            #Earlier call to Test-ModuleManifest adds prefix to functions, now those prefixes need to be remove
            #Prefixes are affixed to the beginning of function, or after '-'
            $originalFunctions = $moduleInfo.ExportedFunctions.Keys | 
                foreach-object { $parts = $_ -split '-', 2; $parts[-1] = $parts[-1] -replace "^$($moduleInfo.Prefix)"; $parts -join '-' }
            $params.Add("FunctionsToExport", $originalFunctions)
        }
        else 
        {
            $params.Add("FunctionsToExport",($moduleInfo.ExportedFunctions.Keys -split ' '))
        }
    }
    elseif ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("FunctionsToExport"))
    {
        $params.Add("FunctionsToExport", $ModuleManifestHashTable['FunctionsToExport'])
    }

    if($AliasesToExport -or $AliasesToExport -is [array])
    {
        $params.Add("AliasesToExport",$AliasesToExport)
    }
    elseif($moduleInfo.ExportedAliases)
    {
        #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("AliasesToExport") -and $ModuleManifestHashTable['AliasesToExport'] -eq '*' `
            -and $moduleInfo.ExportedAliases.Keys.Count -eq 0)
        {
            $params.Add("AliasesToExport", $ModuleManifestHashTable['AliasesToExport'])
        }
        elseif($moduleInfo.Prefix)
        {
            #Earlier call to Test-ModuleManifest adds prefix to aliases, now those prefixes need to be removed
            #Prefixes are affixed to the beginning of function, or after '-'
            $originalAliases = $moduleInfo.ExportedAliases.Keys | 
                ForEach-Object { $parts = $_ -split '-', 2; $parts[-1] = $parts[-1] -replace "^$($moduleInfo.Prefix)"; $parts -join '-' }
            $params.Add("AliasesToExport", $originalAliases)   
        }
        else 
        {
            $params.Add("AliasesToExport",($moduleInfo.ExportedAliases.Keys -split ' '))
        }
    }
    elseif ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("AliasesToExport"))
    {
        $params.Add("AliasesToExport", $ModuleManifestHashTable['AliasesToExport'])
    }

    if($VariablesToExport)
    {
        $params.Add("VariablesToExport",$VariablesToExport)
    }
    elseif($moduleInfo.ExportedVariables)
    {
         #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("VariablesToExport") -and $ModuleManifestHashTable['VariablesToExport'] -eq '*' `
            -and $moduleInfo.ExportedVariables.Keys.Count -eq 0)
        {
            $params.Add("VariablesToExport", $ModuleManifestHashTable['VariablesToExport'])
        }
        else {
            #Since $moduleInfo.ExportedAliases is a hashtable, we need to take the name of the
            #variables and make them into a list
            $params.Add("VariablesToExport",($moduleInfo.ExportedVariables.Keys -split ' '))
        }
    }

    if($CmdletsToExport -or $CmdletsToExport -is [array])
    {
        $params.Add("CmdletsToExport", $CmdletsToExport)
    }
    elseif($moduleInfo.ExportedCmdlets)
    {
        #Get the original module info from ManifestHashTable
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("CmdletsToExport") -and $ModuleManifestHashTable['CmdletsToExport'] -eq '*' `
          -and $moduleInfo.ExportedCmdlets.Count -eq 0)
        {
            $params.Add("CmdletsToExport", $ModuleManifestHashTable['CmdletsToExport'])
        }
        elseif($moduleInfo.Prefix)
        {
            #Earlier call to Test-ModuleManifest adds prefix to cmdlets, now those prefixes need to be removed
            #Prefixes are affixed to the beginning of function, or after '-'
            $originalCmdlets = $moduleInfo.ExportedCmdlets.Keys | 
                ForEach-Object { $parts = $_ -split '-', 2; $parts[-1] = $parts[-1] -replace "^$($moduleInfo.Prefix)"; $parts -join '-' }
            $params.Add("CmdletsToExport", $originalCmdlets)
        }
        else
        {
            $params.Add("CmdletsToExport",($moduleInfo.ExportedCmdlets.Keys -split ' '))
        }
    }
    elseif ($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("CmdletsToExport"))
    {
        $params.Add("CmdletsToExport", $ModuleManifestHashTable['CmdletsToExport'])
    }

    if($DscResourcesToExport)
    {
        #DscResourcesToExport field is not available in PowerShell version lower than 5.0

        if  (($PSVersionTable.PSVersion -lt '5.0.0') -or ($PowerShellVersion -and $PowerShellVersion -lt '5.0') `
             -or (-not $PowerShellVersion -and $moduleInfo.PowerShellVersion -and $moduleInfo.PowerShellVersion -lt '5.0') `
             -or (-not $PowerShellVersion -and -not $moduleInfo.PowerShellVersion))
        {
                ThrowError -ExceptionName "System.ArgumentException" `
                   -ExceptionMessage $LocalizedData.ExportedDscResourcesNotSupportedOnLowerPowerShellVersion `
                   -ErrorId "ExportedDscResourcesNotSupported" `
                   -ExceptionObject $DscResourcesToExport `
                   -CallerPSCmdlet $PSCmdlet `
                   -ErrorCategory InvalidArgument
                return
        }

        $params.Add("DscResourcesToExport",$DscResourcesToExport)
    }
    elseif(Microsoft.PowerShell.Utility\Get-Member -InputObject $moduleInfo -name "ExportedDscResources")
    {
        if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("DscResourcesToExport") -and $ModuleManifestHashTable['DscResourcesToExport'] -eq '*' `
                -and $moduleInfo.ExportedDscResources.Count -eq 0)
        {
            $params.Add("DscResourcesToExport", $ModuleManifestHashTable['DscResourcesToExport']) 
        }
        else 
        {
            $params.Add("DscResourcesToExport", $moduleInfo.ExportedDscResources)
        }
    }

    if($CompatiblePSEditions)
    {
        # CompatiblePSEditions field is not available in PowerShell version lower than 5.1
        #
        if  (($PSVersionTable.PSVersion -lt '5.1.0') -or ($PowerShellVersion -and $PowerShellVersion -lt '5.1') `
             -or (-not $PowerShellVersion -and $moduleInfo.PowerShellVersion -and $moduleInfo.PowerShellVersion -lt '5.1') `
             -or (-not $PowerShellVersion -and -not $moduleInfo.PowerShellVersion))
        {
                ThrowError -ExceptionName 'System.ArgumentException' `
                           -ExceptionMessage $LocalizedData.CompatiblePSEditionsNotSupportedOnLowerPowerShellVersion `
                           -ErrorId 'CompatiblePSEditionsNotSupported' `
                           -ExceptionObject $CompatiblePSEditions `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument
                return
        }

        $params.Add('CompatiblePSEditions', $CompatiblePSEditions)
    }
    elseif( (Microsoft.PowerShell.Utility\Get-Member -InputObject $moduleInfo -name 'CompatiblePSEditions') -and
            $moduleInfo.CompatiblePSEditions)
    {
        $params.Add('CompatiblePSEditions', $moduleInfo.CompatiblePSEditions)
    }

    if($HelpInfoUri)
    {
        $params.Add("HelpInfoUri",$HelpInfoUri)
    }
    elseif($moduleInfo.HelpInfoUri)
    {
        $params.Add("HelpInfoUri",$moduleInfo.HelpInfoUri)
    }

    if($DefaultCommandPrefix)
    {
        $params.Add("DefaultCommandPrefix",$DefaultCommandPrefix)
    }
    elseif($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey("DefaultCommandPrefix") -and $ModuleManifestHashTable.DefaultCommandPrefix)
    {
        $params.Add("DefaultCommandPrefix",$ModuleManifestHashTable.DefaultCommandPrefix)
    }

    #Create a temp file within the directory and generate a new temporary manifest with the input
    $tempPath = Microsoft.PowerShell.Management\Join-Path -Path $moduleInfo.ModuleBase -ChildPath "PSGet_$($moduleInfo.Name).psd1"
    $params.Add("Path",$tempPath)

    try
    {
        #Terminates if there is error creating new module manifest
        try{
            Microsoft.PowerShell.Core\New-ModuleManifest @params -Confirm:$false -WhatIf:$false
            #If company name is the disposable name created for the new module manifest, it will be changed back to ''
            (Get-Content -Path $tempPath) | ForEach-Object {$_ -Replace '__UPDATEDCOMPANYNAMETOBEREPLACEDINFUNCTION__', ''} | Set-Content -Path $tempPath -Confirm:$false -WhatIf:$false
        }
        catch
        {
            $ErrorMessage = $LocalizedData.UpdatedModuleManifestNotValid -f ($Path, $_.Exception.Message)
            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $ErrorMessage `
                       -ErrorId "NewModuleManifestFailure" `
                       -ExceptionObject $params `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
            return
        }

        #Manually update the section in PrivateData since New-ModuleManifest works differently on different PS version
        $PrivateDataInput = ""
        $ExistingData = $moduleInfo.PrivateData
        $Data = @{}
        if($ExistingData)
        {
            foreach($key in $ExistingData.Keys)
            {
                if($key -ne "PSData"){
                    $Data.Add($key,$ExistingData[$key])
                }
                else
                {
                    $PSData = $ExistingData["PSData"]
                    foreach($entry in $PSData.Keys)
                    {
                        $Data.Add($entry,$PSData[$Entry])
                    }
                }
            }
        }

        if($PrivateData)
        {
            foreach($key in $PrivateData.Keys)
            {
                #if user provides PSData within PrivateData, we will parse through the PSData
                if($key -ne "PSData")
                {
                    $Data[$key] = $PrivateData[$Key]
                }

                else
                {
                    $PSData = $ExistingData["PSData"]
                    foreach($entry in $PSData.Keys)
                    {
                        $Data[$entry] = $PSData[$entry]
                    }
                }
            }
        }

        #Tags is a read-only property
        if($Tags)
        {
           $Data["Tags"] = $Tags
        }

        #The following Uris and ReleaseNotes cannot be empty
        if($ProjectUri)
        {
            $Data["ProjectUri"] = $ProjectUri
        }

        if($LicenseUri)
        {
            $Data["LicenseUri"] = $LicenseUri
        }

        if($IconUri)
        {
            $Data["IconUri"] = $IconUri
        }
        if($RequireLicenseAcceptance)
        {
            $Data["RequireLicenseAcceptance"] = $RequireLicenseAcceptance
        }

        if($ReleaseNotes)
        {
            #If value is provided as an array, we append the string.
            $Data["ReleaseNotes"] = $($ReleaseNotes -join "`r`n")
        }

        if ($Prerelease)
        {
            $result = ValidateAndGet-VersionPrereleaseStrings -Version $params["ModuleVersion"] -Prerelease $Prerelease -CallerPSCmdlet $PSCmdlet
            if (-not $result)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $validatedPrerelease = $result["Prerelease"]
            $Data[$script:Prerelease] = $validatedPrerelease
        }

        if($ExternalModuleDependencies)
        {
            #ExternalModuleDependencies have to be specified either under $RequiredModules or $NestedModules
            #Extract all the module names specified in the moduleInfo of NestedModules and RequiredModules
            $DependentModuleNames = @()
            foreach($moduleInfo in $params["NestedModules"])
            {
                if($moduleInfo.GetType() -eq [System.Collections.Hashtable])
                {
                    $DependentModuleNames += $moduleInfo.ModuleName
                }
            }

            foreach($moduleInfo in $params["RequiredModules"])
            {
                if($moduleInfo.GetType() -eq [System.Collections.Hashtable])
                {
                    $DependentModuleNames += $moduleInfo.ModuleName
                }
            }

            foreach($dependency in $ExternalModuleDependencies)
            {
                if($params["NestedModules"] -notcontains $dependency -and
                $params["RequiredModules"] -notContains $dependency -and
                $DependentModuleNames -notcontains $dependency)
                {
                    $message = $LocalizedData.ExternalModuleDependenciesNotSpecifiedInRequiredOrNestedModules -f ($dependency)
                    ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidExternalModuleDependencies" `
                        -ExceptionObject $Exception `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument
                        return
                    }
            }
            if($Data.ContainsKey("ExternalModuleDependencies"))
            {
                $Data["ExternalModuleDependencies"] = $ExternalModuleDependencies
            }
            else
            {
                $Data.Add("ExternalModuleDependencies", $ExternalModuleDependencies)
            }
        }
        if($PackageManagementProviders)
        {
            #Check if the provided value is within the relative path
            $ModuleBase = Microsoft.PowerShell.Management\Split-Path $Path -Parent
            $Files = Microsoft.PowerShell.Management\Get-ChildItem -Path $ModuleBase
            foreach($provider in $PackageManagementProviders)
            {
                if ($Files.Name -notcontains $provider)
                {
                    $message = $LocalizedData.PackageManagementProvidersNotInModuleBaseFolder -f ($provider,$ModuleBase)
                    ThrowError -ExceptionName "System.ArgumentException" `
                               -ExceptionMessage $message `
                               -ErrorId "InvalidPackageManagementProviders" `
                               -ExceptionObject $PackageManagementProviders `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidArgument
                    return
                }
            }

            $Data["PackageManagementProviders"] = $PackageManagementProviders
        }
        $PrivateDataInput = Get-PrivateData -PrivateData $Data

        #Replace the PrivateData section by first locating the linenumbers of start line and endline.
        $PrivateDataBegin = Select-String -Path $tempPath -Pattern "PrivateData ="
        $PrivateDataBeginLine = $PrivateDataBegin.LineNumber

        $newManifest = Microsoft.PowerShell.Management\Get-Content -Path $tempPath
        #Look up the endline of PrivateData section by finding the matching brackets since private data could
        #consist of multiple pairs of brackets.
        $PrivateDataEndLine=0
        if($PrivateDataBegin -match "@{")
        {
            $leftBrace = 0
            $EndLineOfFile = $newManifest.Length-1

            For($i = $PrivateDataBeginLine;$i -lt $EndLineOfFile; $i++)
            {
                if($newManifest[$i] -match "{")
                {
                    $leftBrace ++
                }
                elseif($newManifest[$i] -match "}")
                {
                    if($leftBrace -gt 0)
                    {
                        $leftBrace --
                    }
                    else
                    {
                       $PrivateDataEndLine = $i
                       break
                    }
                }
            }
        }


        try
        {
            if($PrivateDataEndLine -ne 0)
            {
                #If PrivateData section has more than one line, we will remove the old content and insert the new PrivataData
                $newManifest  | where {$_.readcount -le $PrivateDataBeginLine -or $_.readcount -gt $PrivateDataEndLine+1} `
                | ForEach-Object {
                    $_
                    if($_ -match "PrivateData = ")
                    {
                        $PrivateDataInput
                    }
                  } | Set-Content -Path $tempPath -Confirm:$false -WhatIf:$false
            }

            #In lower version, PrivateData is just a single line
            else
            {
                $PrivateDataForDownlevelPS = "PrivateData = @{ `n"+$PrivateDataInput

                $newManifest  | where {$_.readcount -le $PrivateDataBeginLine -or $_.readcount -gt $PrivateDataBeginLine } `
                | ForEach-Object {
                    $_
                    if($_ -match "PrivateData = ")
                    {
                       $PrivateDataForDownlevelPS
                    }
                } | Set-Content -Path $tempPath -Confirm:$false -WhatIf:$false
            }

            #Verify the new module manifest is valid
            $testModuleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $tempPath `
                                                                        -Verbose:$VerbosePreference ` -ErrorAction Stop
        }
        #Catch the exceptions from Test-ModuleManifest
        catch
        {
            $message = $LocalizedData.UpdatedModuleManifestNotValid -f ($Path, $_.Exception.Message)

            ThrowError -ExceptionName "System.ArgumentException" `
                       -ExceptionMessage $message `
                       -ErrorId "UpdateManifestFileFail" `
                       -ExceptionObject $_.Exception `
                       -CallerPSCmdlet $PSCmdlet `
                       -ErrorCategory InvalidArgument
            return
        }


        $newContent = Microsoft.PowerShell.Management\Get-Content -Path $tempPath

        #Remove the PSGet_ prepended to the original manifest name due to the temp file name
        $newContent[1] = $newContent[1] -replace "'PSGet_", "'"

        try
        {
            #Ask for confirmation of the new manifest before replacing the original one
            if($PSCmdlet.ShouldProcess($Path,$LocalizedData.UpdateManifestContentMessage+$newContent))
            {
                Microsoft.PowerShell.Management\Set-Content -Path $Path -Value $newContent -Confirm:$false -WhatIf:$false
            }

            #Return the new content if -PassThru is specified
            if($PassThru)
            {
                return $newContent
            }
        }
        catch
        {
            $message = $LocalizedData.ManifestFileReadWritePermissionDenied -f ($Path)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "ManifestFileReadWritePermissionDenied" `
                        -ExceptionObject $Path `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument
        }
    }
    finally
    {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
    }
}
# SIG # Begin signature block
# MIInJwYJKoZIhvcNAQcCoIInGDCCJxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDKFxKIO5g5eR+h
# W7NwJpK1SJC1n/bEgCch5r+LYxdvFaCCDLowggX1MIID3aADAgECAhMzAAACHU0Z
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
# KoZIhvcNAQkEMSIEIOYhBfSGHkYrU8G8OnYwqCAU3jx9RIToRjrj5GP9bqMDMEIG
# CisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEARgnWekT0MIGvRY2R
# PWP30EJ73r/ivrX2VXMavoCbvuX5mja30YRh3o31SSTR9cyetpk0NS1VaAipsAFc
# lRs9qoMlOUd7Z/Ra9nzG99kFTuXWn8aglLOceyyV2Jn/tdQnjg++YmjBPTLausJe
# Mpos6DPNz7iNCo59w+ST06kSO4vrE00RzxyQnsbBUjpqzEoejcT3F7NG7PFuvuKc
# lO4fMMZ2HMi4jJRKhVwvTxmllt+2+S2jFsVQNnJtMqSgj+GI6KZCSdhq1qTCI4tf
# bjHxUgPMSjUjLdbGo1l3bw/gnJwbNvI7pQBSs4qf1dMk+tvgoy5H5XUarf0LVt9V
# zfmuFqGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sGCSqGSIb3DQEHAqCCF2ww
# ghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9
# MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCBRTlRKZcj4wVcd
# Kg/VjsVfQBSKU217d5PWzYgAVyfYaAIGavNtm9sfGBMyMDI2MTExMDIyMDYxMi45
# MTFaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIH626YSR
# yvOlHGKXh4HMYGoXDxs+wG210e63L37unyeRMIH6BgsqhkiG9w0BCRACLzGB6jCB
# 5zCB5DCBvQQgzDJcYWdM2xlEGuzoY38FtXSiRo0/dUFiosWNSwWduCowgZgwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAiY1tD5nQ5P2HwAB
# AAACJjAiBCArqEOPvSz4m0kSkDyNoz4Cc7jcRfe6OInHN5wLrolYCDANBgkqhkiG
# 9w0BAQsFAASCAgAOkQqrmwsch794bH4qMuew2oJ4cBNHiR9UQz0tugPe47OTXxUS
# q8cXP7pYOqsFczFUihaHNdOxwk7alSju0n8WiLq2UW9yZn/FMZe9NRJZTQfmW+3H
# xwAvnaJUj+YWswmPo4J2epGukYwAqNwxudFOx672uvx6e4sgJnsaLSUPqTqJB/Ts
# CXEdKwhn+Z/tWnkJp0fI4GOq4DG/h2epaHIQeY7XBB6RNkMR8CJgSeslOZBRI9MX
# jhPF/4hQKSJ8uyrh3z5Y6dvkSUVxohAX7ECEfjaRx+tLep5Q6VZKTXCBZK9f5HZm
# P5oyrJ7DAoofzrSUOMS1nv9dGZZech7TXoIMd4txyEATzQuGKMTa0whcn0X8VlCa
# IG0uhCzJFJ7U+OuqG3nkNjO7bkDT1iOYLUpynQs/XMIH/iWuNqsb5MSnRb/DmRCB
# LcoB3Ft4FkWy+H7yTyR/VrFZtFRoQQSEAiCWLNSCo8ltJ87LAg3sHy5AvfomPZ1F
# kMtHMq2VgAr+BnKPi//xTVKkbsDpI8gSbJ1e/JtYXZz4RBDVjodqvGM6Crgf7yLR
# MLwpwYKyu7RvFTKujU3cZv6LwmnBb+qyGsdx/ZXKgjh49builHOmiE1gupG0J3bK
# d5wfjXpSwH8gLwF6UULoXpAvyyoh0MXT1qSaU+vGFFf55zbZoINNK0yBRA==
# SIG # End signature block
