
#########################################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# PowerShellGet Module
#
#########################################################################################

Microsoft.PowerShell.Core\Set-StrictMode -Version Latest

#region script variables

$script:IsInbox = $PSHOME.EndsWith('\WindowsPowerShell\v1.0', [System.StringComparison]::OrdinalIgnoreCase)
$script:IsWindows = (-not (Get-Variable -Name IsWindows -ErrorAction Ignore)) -or $IsWindows
$script:IsLinux = (Get-Variable -Name IsLinux -ErrorAction Ignore) -and $IsLinux
$script:IsMacOS = (Get-Variable -Name IsMacOS -ErrorAction Ignore) -and $IsMacOS
$script:IsCoreCLR = $PSVersionTable.ContainsKey('PSEdition') -and $PSVersionTable.PSEdition -eq 'Core'
$script:IsNanoServer = & {
    if (!$script:IsWindows) {
        return $false
    }

    $serverLevelsPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels\'
    if (Test-Path -Path $serverLevelsPath) {
        $NanoItem = Get-ItemProperty -Name NanoServer -Path $serverLevelsPath -ErrorAction Ignore
        if ($NanoItem -and ($NanoItem.NanoServer -eq 1)) {
            return $true
        }
    }
    return $false
}

if ($script:IsInbox) {
    $script:ProgramFilesPSPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell"
}
elseif ($script:IsCoreCLR) {
    if ($script:IsWindows) {
        $script:ProgramFilesPSPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell'
    }
    else {
        $script:ProgramFilesPSPath = Microsoft.PowerShell.Management\Split-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('SHARED_MODULES')) -Parent
    }
}

try {
    $script:MyDocumentsFolderPath = [Environment]::GetFolderPath("MyDocuments")
}
catch {
    $script:MyDocumentsFolderPath = $null
}

if ($script:IsInbox) {
    $script:MyDocumentsPSPath = if ($script:MyDocumentsFolderPath) {
        Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsFolderPath -ChildPath "WindowsPowerShell"
    }
    else {
        Microsoft.PowerShell.Management\Join-Path -Path $env:USERPROFILE -ChildPath "Documents\WindowsPowerShell"
    }
}
elseif ($script:IsCoreCLR) {
    if ($script:IsWindows) {
        $script:MyDocumentsPSPath = if ($script:MyDocumentsFolderPath) {
            Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsFolderPath -ChildPath 'PowerShell'
        }
        else {
            Microsoft.PowerShell.Management\Join-Path -Path $HOME -ChildPath "Documents\PowerShell"
        }
    }
    else {
        $script:MyDocumentsPSPath = Microsoft.PowerShell.Management\Split-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('USER_MODULES')) -Parent
    }
}

$script:ProgramFilesModulesPath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesPSPath -ChildPath 'Modules'
$script:MyDocumentsModulesPath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsPSPath -ChildPath 'Modules'

$script:ProgramFilesScriptsPath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesPSPath -ChildPath 'Scripts'
$script:MyDocumentsScriptsPath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsPSPath -ChildPath 'Scripts'

$script:PSGetPath = [pscustomobject]@{
    AllUsersModules    = $script:ProgramFilesModulesPath
    AllUsersScripts    = $script:ProgramFilesScriptsPath
    CurrentUserModules = $script:MyDocumentsModulesPath
    CurrentUserScripts = $script:MyDocumentsScriptsPath
    PSTypeName         = 'Microsoft.PowerShell.Commands.PSGetPath'
}

$script:TempPath = [System.IO.Path]::GetTempPath()
$script:PSGetItemInfoFileName = "PSGetModuleInfo.xml"

if ($script:IsWindows) {
    $script:PSGetProgramDataPath = Microsoft.PowerShell.Management\Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
    $script:PSGetAppLocalPath = Microsoft.PowerShell.Management\Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
}
else {
    $script:PSGetProgramDataPath = Microsoft.PowerShell.Management\Join-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('CONFIG')) -ChildPath 'PowerShellGet'
    $script:PSGetAppLocalPath = Microsoft.PowerShell.Management\Join-Path -Path ([System.Management.Automation.Platform]::SelectProductNameForDirectory('CACHE')) -ChildPath 'PowerShellGet'
}

$script:PSGetModuleSourcesFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:PSGetAppLocalPath -ChildPath "PSRepositories.xml"
$script:PSGetModuleSources = $null
$script:PSGetInstalledModules = $null
$script:PSGetSettingsFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:PSGetAppLocalPath -ChildPath "PowerShellGetSettings.xml"
$script:PSGetSettings = $null

$script:MyDocumentsInstalledScriptInfosPath = Microsoft.PowerShell.Management\Join-Path -Path $script:MyDocumentsScriptsPath -ChildPath 'InstalledScriptInfos'
$script:ProgramFilesInstalledScriptInfosPath = Microsoft.PowerShell.Management\Join-Path -Path $script:ProgramFilesScriptsPath -ChildPath 'InstalledScriptInfos'

$script:IsRunningAsElevated = $true
$script:IsRunningAsElevatedTested = $false

$script:InstalledScriptInfoFileName = 'InstalledScriptInfo.xml'
$script:PSGetInstalledScripts = $null

# Public PSGallery module source name and location
$Script:PSGalleryModuleSource = "PSGallery"
$Script:PSGallerySourceUri = 'https://www.powershellgallery.com/api/v2'
$Script:PSGalleryPublishUri = 'https://www.powershellgallery.com/api/v2/package/'
$Script:PSGalleryScriptSourceUri = 'https://www.powershellgallery.com/api/v2/items/psscript'

# PSGallery V3 Source
$Script:PSGalleryV3SourceUri = 'https://www.powershellgallery.com/api/v3'

$Script:ResponseUri = "ResponseUri"
$Script:StatusCode = "StatusCode"
$Script:Exception = "Exception"

$script:PSModuleProviderName = 'PowerShellGet'
$script:PackageManagementProviderParam = "PackageManagementProvider"
$script:PublishLocation = "PublishLocation"
$script:ScriptSourceLocation = 'ScriptSourceLocation'
$script:ScriptPublishLocation = 'ScriptPublishLocation'
$script:Proxy = 'Proxy'
$script:ProxyCredential = 'ProxyCredential'
$script:Credential = 'Credential'
$script:VSTSAuthenticatedFeedsDocUrl = 'https://go.microsoft.com/fwlink/?LinkID=698608'
$script:Prerelease = "Prerelease"

$script:NuGetProviderName = "NuGet"
$script:NuGetProviderVersion = [Version]'2.8.5.201'

$script:SupportsPSModulesFeatureName = "supports-powershell-modules"
$script:FastPackRefHashtable = @{ }
$script:NuGetBinaryProgramDataPath = if ($script:IsWindows) { "$env:ProgramFiles\PackageManagement\ProviderAssemblies" }
$script:NuGetBinaryLocalAppDataPath = if ($script:IsWindows) { "$env:LOCALAPPDATA\PackageManagement\ProviderAssemblies" }
# go fwlink for 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
$script:NuGetClientSourceURL = 'https://aka.ms/psget-nugetexe'
$script:NuGetExeMinRequiredVersion = [Version]'4.1.0'
$script:NuGetExeName = 'NuGet.exe'
$script:NuGetExePath = $null
$script:NuGetExeVersion = $null
$script:NuGetProvider = $null
$script:DotnetCommandName = 'dotnet'
$script:MinimumDotnetCommandVersion = [Version]'2.0.0'
$script:DotnetInstallUrl = 'https://aka.ms/dotnet-install-script'
$script:DotnetCommandPath = $null
# PowerShellGetFormatVersion will be incremented when we change the .nupkg format structure.
# PowerShellGetFormatVersion is in the form of Major.Minor.
# Minor is incremented for the backward compatible format change.
# Major is incremented for the breaking change.
$script:PSGetRequireLicenseAcceptanceFormatVersion = [Version]'2.0'
$script:CurrentPSGetFormatVersion = $script:PSGetRequireLicenseAcceptanceFormatVersion
$script:PSGetFormatVersion = "PowerShellGetFormatVersion"
$script:SupportedPSGetFormatVersionMajors = @("1", "2")
$script:ModuleReferences = 'Module References'
$script:AllVersions = "AllVersions"
$script:AllowPrereleaseVersions = "AllowPrereleaseVersions"
$script:Filter = "Filter"
$script:IncludeValidSet = @('DscResource', 'Cmdlet', 'Function', 'Workflow', 'RoleCapability')
$script:DscResource = "PSDscResource"
$script:Command = "PSCommand"
$script:Cmdlet = "PSCmdlet"
$script:Function = "PSFunction"
$script:Workflow = "PSWorkflow"
$script:RoleCapability = 'PSRoleCapability'
$script:Includes = "PSIncludes"
$script:Tag = "Tag"
$script:NotSpecified = '_NotSpecified_'
$script:PSGetModuleName = 'PowerShellGet'
$script:FindByCanonicalId = 'FindByCanonicalId'
$script:InstalledLocation = 'InstalledLocation'
$script:PSArtifactType = 'Type'
$script:PSArtifactTypeModule = 'Module'
$script:PSArtifactTypeScript = 'Script'
$script:All = 'All'

$script:Name = 'Name'
$script:Version = 'Version'
$script:Guid = 'Guid'
$script:Path = 'Path'
$script:ScriptBase = 'ScriptBase'
$script:Description = 'Description'
$script:Author = 'Author'
$script:CompanyName = 'CompanyName'
$script:Copyright = 'Copyright'
$script:Tags = 'Tags'
$script:LicenseUri = 'LicenseUri'
$script:ProjectUri = 'ProjectUri'
$script:IconUri = 'IconUri'
$script:RequiredModules = 'RequiredModules'
$script:ExternalModuleDependencies = 'ExternalModuleDependencies'
$script:ReleaseNotes = 'ReleaseNotes'
$script:RequiredScripts = 'RequiredScripts'
$script:ExternalScriptDependencies = 'ExternalScriptDependencies'
$script:DefinedCommands = 'DefinedCommands'
$script:DefinedFunctions = 'DefinedFunctions'
$script:DefinedWorkflows = 'DefinedWorkflows'
$script:TextInfo = (Get-Culture).TextInfo
$script:PrivateData = 'PrivateData'

$script:PSScriptInfoProperties = @($script:Name
    $script:Version,
    $script:Guid,
    $script:Path,
    $script:ScriptBase,
    $script:Description,
    $script:Author,
    $script:CompanyName,
    $script:Copyright,
    $script:Tags,
    $script:ReleaseNotes,
    $script:RequiredModules,
    $script:ExternalModuleDependencies,
    $script:RequiredScripts,
    $script:ExternalScriptDependencies,
    $script:LicenseUri,
    $script:ProjectUri,
    $script:IconUri,
    $script:DefinedCommands,
    $script:DefinedFunctions,
    $script:DefinedWorkflows,
    $script:PrivateData
)

$script:SystemEnvironmentKey = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
$script:UserEnvironmentKey = 'HKCU:\Environment'
$script:SystemEnvironmentVariableMaximumLength = 1024
$script:UserEnvironmentVariableMaximumLength = 255
$script:EnvironmentVariableTarget = @{ Process = 0; User = 1; Machine = 2 }

# Wildcard pattern matching configuration.
$script:wildcardOptions = [System.Management.Automation.WildcardOptions]::CultureInvariant -bor `
    [System.Management.Automation.WildcardOptions]::IgnoreCase

$script:DynamicOptionTypeMap = @{
    0 = [string]; # String
    1 = [string[]]; # StringArray
    2 = [int]; # Int
    3 = [switch]; # Switch
    4 = [string]; # Folder
    5 = [string]; # File
    6 = [string]; # Path
    7 = [Uri]; # Uri
    8 = [SecureString]; #SecureString
}
#endregion script variables

#region Module message resolvers
$script:PackageManagementMessageResolverScriptBlock = {
    param($i, $Message)
    return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
}

$script:PackageManagementSaveModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallModulewhatIfMessage
    $QuerySaveUntrustedPackage = $LocalizedData.QuerySaveUntrustedPackage

    switch ($i) {
        'ActionInstallPackage' { return "Save-Module" }
        'QueryInstallUntrustedPackage' { return $QuerySaveUntrustedPackage }
        'TargetPackage' { return $PackageTarget }
        Default {
            $Message = $Message -creplace "Install", "Download"
            $Message = $Message -creplace "install", "download"
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementInstallModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallModulewhatIfMessage

    switch ($i) {
        'ActionInstallPackage' { return "Install-Module" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUnInstallModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallModulewhatIfMessage
    switch ($i) {
        'ActionUninstallPackage' { return "Uninstall-Module" }
        'TargetPackageVersion' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUpdateModuleMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = ($LocalizedData.UpdateModulewhatIfMessage -replace "__OLDVERSION__", $($psgetItemInfo.Version))
    switch ($i) {
        'ActionInstallPackage' { return "Update-Module" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolver -MsgId $i, -Message $Message)
        }
    }
}

# Modules allowed to install non-Microsoft signed modules over Microsoft signed modules
$script:WhitelistedModules = @{
    "Pester"     = $true
    "PSReadline" = $true
}

function PackageManagementMessageResolver($MsgID, $Message) {
    $NoMatchFound = $LocalizedData.NoMatchFound
    $SourceNotFound = $LocalizedData.SourceNotFound
    $ModuleIsNotTrusted = $LocalizedData.ModuleIsNotTrusted
    $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
    $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedPackage

    switch ($MsgID) {
        'NoMatchFound' { return $NoMatchFound }
        'SourceNotFound' { return $SourceNotFound }
        'CaptionPackageNotTrusted' { return $ModuleIsNotTrusted }
        'CaptionSourceNotTrusted' { return $RepositoryIsNotTrusted }
        'QueryInstallUntrustedPackage' { return $QueryInstallUntrustedPackage }
        Default {
            if ($Message) {
                $tempMessage = $Message -creplace "PackageSource", "PSRepository"
                $tempMessage = $tempMessage -creplace "packagesource", "psrepository"
                $tempMessage = $tempMessage -creplace "Package", "Module"
                $tempMessage = $tempMessage -creplace "package", "module"
                $tempMessage = $tempMessage -creplace "Sources", "Repositories"
                $tempMessage = $tempMessage -creplace "sources", "repositories"
                $tempMessage = $tempMessage -creplace "Source", "Repository"
                $tempMessage = $tempMessage -creplace "source", "repository"

                return $tempMessage
            }
        }
    }
}

#endregion Module message resolvers

#region Script message resolvers
$script:PackageManagementMessageResolverScriptBlockForScriptCmdlets = {
    param($i, $Message)
    return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
}

$script:PackageManagementSaveScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage
    $QuerySaveUntrustedPackage = $LocalizedData.QuerySaveUntrustedScriptPackage

    switch ($i) {
        'ActionInstallPackage' { return "Save-Script" }
        'QueryInstallUntrustedPackage' { return $QuerySaveUntrustedPackage }
        'TargetPackage' { return $PackageTarget }
        Default {
            $Message = $Message -creplace "Install", "Download"
            $Message = $Message -creplace "install", "download"
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementInstallScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage

    switch ($i) {
        'ActionInstallPackage' { return "Install-Script" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUnInstallScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = $LocalizedData.InstallScriptwhatIfMessage
    switch ($i) {
        'ActionUninstallPackage' { return "Uninstall-Script" }
        'TargetPackageVersion' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

$script:PackageManagementUpdateScriptMessageResolverScriptBlock = {
    param($i, $Message)
    $PackageTarget = ($LocalizedData.UpdateScriptwhatIfMessage -replace "__OLDVERSION__", $($psgetItemInfo.Version))
    switch ($i) {
        'ActionInstallPackage' { return "Update-Script" }
        'TargetPackage' { return $PackageTarget }
        Default {
            return (PackageManagementMessageResolverForScripts -MsgId $i, -Message $Message)
        }
    }
}

function PackageManagementMessageResolverForScripts($MsgID, $Message) {
    $NoMatchFound = $LocalizedData.NoMatchFoundForScriptName
    $SourceNotFound = $LocalizedData.SourceNotFound
    $ScriptIsNotTrusted = $LocalizedData.ScriptIsNotTrusted
    $RepositoryIsNotTrusted = $LocalizedData.RepositoryIsNotTrusted
    $QueryInstallUntrustedPackage = $LocalizedData.QueryInstallUntrustedScriptPackage

    switch ($MsgID) {
        'NoMatchFound' { return $NoMatchFound }
        'SourceNotFound' { return $SourceNotFound }
        'CaptionPackageNotTrusted' { return $ScriptIsNotTrusted }
        'CaptionSourceNotTrusted' { return $RepositoryIsNotTrusted }
        'QueryInstallUntrustedPackage' { return $QueryInstallUntrustedPackage }
        Default {
            if ($Message) {
                $tempMessage = $Message -creplace "PackageSource", "PSRepository"
                $tempMessage = $tempMessage -creplace "packagesource", "psrepository"
                $tempMessage = $tempMessage -creplace "Package", "Script"
                $tempMessage = $tempMessage -creplace "package", "script"
                $tempMessage = $tempMessage -creplace "Sources", "Repositories"
                $tempMessage = $tempMessage -creplace "sources", "repositories"
                $tempMessage = $tempMessage -creplace "Source", "Repository"
                $tempMessage = $tempMessage -creplace "source", "repository"

                return $tempMessage
            }
        }
    }
}

#endregion Script message resolvers

#region Add .Net type for Telemetry APIs and WebProxy

# Check and add InternalWebProxy type
if ( -not ('Microsoft.PowerShell.Commands.PowerShellGet.InternalWebProxy' -as [Type])) {
    $RequiredAssembliesForInternalWebProxy = @(
        [System.Net.IWebProxy].Assembly.FullName,
        [System.Uri].Assembly.FullName
    )

    $InternalWebProxySource = @'
using System;
using System.Net;

namespace Microsoft.PowerShell.Commands.PowerShellGet
{
    /// <summary>
    /// Used by Ping-Endpoint function to supply webproxy to HttpClient
    /// We cannot use System.Net.WebProxy because this is not available on CoreClr
    /// </summary>
    public class InternalWebProxy : IWebProxy
    {
        Uri _proxyUri;
        ICredentials _credentials;

        public InternalWebProxy(Uri uri, ICredentials credentials)
        {
            Credentials = credentials;
            _proxyUri = uri;
        }

        /// <summary>
        /// Credentials used by WebProxy
        /// </summary>
        public ICredentials Credentials
        {
            get
            {
                return _credentials;
            }
            set
            {
                _credentials = value;
            }
        }

        public Uri GetProxy(Uri destination)
        {
            return _proxyUri;
        }

        public bool IsBypassed(Uri host)
        {
            return false;
        }
    }
}
'@

    try {
        $AddType_prams = @{
            TypeDefinition = $InternalWebProxySource
            Language       = 'CSharp'
            ErrorAction    = 'SilentlyContinue'
        }
        if (-not $script:IsCoreCLR -or $script:IsNanoServer) {
            $AddType_prams['ReferencedAssemblies'] = $RequiredAssembliesForInternalWebProxy
        }
        Add-Type @AddType_prams
    }
    catch {
        Write-Warning -Message "InternalWebProxy: $_"
    }
}

# Check and add Telemetry type
if (('Microsoft.PowerShell.Telemetry.Internal.TelemetryAPI' -as [Type]) -and
    -not ('Microsoft.PowerShell.Commands.PowerShellGet.Telemetry' -as [Type])) {
    $RequiredAssembliesForTelemetry = @(
        [System.Management.Automation.PSCmdlet].Assembly.FullName
    )

    $TelemetrySource = @'
using System;
using System.Management.Automation;

namespace Microsoft.PowerShell.Commands.PowerShellGet
{
    public static class Telemetry
    {
        public static void TraceMessageArtifactsNotFound(string[] artifactsNotFound, string operationName)
        {
            Microsoft.PowerShell.Telemetry.Internal.TelemetryAPI.TraceMessage(operationName, new { ArtifactsNotFound = artifactsNotFound });
        }

        public static void TraceMessageNonPSGalleryRegistration(string sourceLocationType, string sourceLocationHash, string installationPolicy, string packageManagementProvider, string publishLocationHash, string scriptSourceLocationHash, string scriptPublishLocationHash, string operationName)
        {
            Microsoft.PowerShell.Telemetry.Internal.TelemetryAPI.TraceMessage(operationName, new { SourceLocationType = sourceLocationType, SourceLocationHash = sourceLocationHash, InstallationPolicy = installationPolicy, PackageManagementProvider = packageManagementProvider, PublishLocationHash = publishLocationHash, ScriptSourceLocationHash = scriptSourceLocationHash, ScriptPublishLocationHash = scriptPublishLocationHash });
        }
    }
}
'@

    try {
        $AddType_prams = @{
            TypeDefinition = $TelemetrySource
            Language       = 'CSharp'
            ErrorAction    = 'SilentlyContinue'
        }
        $AddType_prams['ReferencedAssemblies'] = $RequiredAssembliesForTelemetry
        Add-Type @AddType_prams
    }
    catch {
        Write-Warning -Message "Telemetry: $_"
    }
}
# Turn ON Telemetry if the infrastructure is present on the machine
$script:TelemetryEnabled = $false
if ('Microsoft.PowerShell.Commands.PowerShellGet.Telemetry' -as [Type]) {
    $telemetryMethods = ([Microsoft.PowerShell.Commands.PowerShellGet.Telemetry] | Get-Member -Static).Name
    if ($telemetryMethods.Contains("TraceMessageArtifactsNotFound") -and $telemetryMethods.Contains("TraceMessageNonPSGalleryRegistration")) {
        $script:TelemetryEnabled = $true
    }
}

# Check and add Win32Helpers type
$script:IsSafeX509ChainHandleAvailable = ($null -ne ('Microsoft.Win32.SafeHandles.SafeX509ChainHandle' -as [Type]))
if ($script:IsWindows -and -not ('Microsoft.PowerShell.Commands.PowerShellGet.Win32Helpers' -as [Type])) {
    $RequiredAssembliesForWin32Helpers = @()
    if ($script:IsSafeX509ChainHandleAvailable) {
        # It is not possible to define a single internal SafeHandle class in PowerShellGet namespace for all the supported versions of .Net Framework including .Net Core.
        # SafeHandleZeroOrMinusOneIsInvalid is not a public class on .Net Core,
        # therefore SafeX509ChainHandle will be used if it is available otherwise InternalSafeX509ChainHandle is defined below.
        #
        # ChainContext is not available on .Net Core, we must have to use SafeX509ChainHandle on .Net Core.
        #
        $SafeX509ChainHandleClassName = 'SafeX509ChainHandle'
        $RequiredAssembliesForWin32Helpers += [Microsoft.Win32.SafeHandles.SafeX509ChainHandle].Assembly.FullName
    }
    else {
        # SafeX509ChainHandle is not available on .Net Framework 4.5 or older versions,
        # therefore InternalSafeX509ChainHandle is defined below.
        #
        $SafeX509ChainHandleClassName = 'InternalSafeX509ChainHandle'
    }

    $Win32HelpersSource = @"
using System;
using System.Net;
using Microsoft.Win32.SafeHandles;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Runtime.ConstrainedExecution;
using System.Runtime.Versioning;
using System.Security;

namespace Microsoft.PowerShell.Commands.PowerShellGet
{
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CERT_CHAIN_POLICY_PARA {
        public CERT_CHAIN_POLICY_PARA(int size) {
            cbSize = (uint) size;
            dwFlags = 0;
            pvExtraPolicyPara = IntPtr.Zero;
        }
        public uint   cbSize;
        public uint   dwFlags;
        public IntPtr pvExtraPolicyPara;
    }

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CERT_CHAIN_POLICY_STATUS {
        public CERT_CHAIN_POLICY_STATUS(int size) {
            cbSize = (uint) size;
            dwError = 0;
            lChainIndex = IntPtr.Zero;
            lElementIndex = IntPtr.Zero;
            pvExtraPolicyStatus = IntPtr.Zero;
        }
        public uint   cbSize;
        public uint   dwError;
        public IntPtr lChainIndex;
        public IntPtr lElementIndex;
        public IntPtr pvExtraPolicyStatus;
    }

    // Internal SafeHandleZeroOrMinusOneIsInvalid class to remove the dependency on .Net Framework 4.6.
    public abstract class InternalSafeHandleZeroOrMinusOneIsInvalid : SafeHandle
    {
        protected InternalSafeHandleZeroOrMinusOneIsInvalid(bool ownsHandle)
            : base(IntPtr.Zero, ownsHandle)
        {
        }

        public override bool IsInvalid
        {
            get
            {
                return handle == IntPtr.Zero || handle == new IntPtr(-1);
            }
        }
    }

    // Internal SafeX509ChainHandle class to remove the dependency on .Net Framework 4.6.
    [SecurityCritical]
    public sealed class InternalSafeX509ChainHandle : InternalSafeHandleZeroOrMinusOneIsInvalid {
        private InternalSafeX509ChainHandle () : base(true) {}

        internal InternalSafeX509ChainHandle (IntPtr handle) : base (true) {
            SetHandle(handle);
        }

        internal static InternalSafeX509ChainHandle InvalidHandle {
            get { return new InternalSafeX509ChainHandle(IntPtr.Zero); }
        }

        [SecurityCritical]
        override protected bool ReleaseHandle()
        {
            CertFreeCertificateChain(handle);
            return true;
        }

        [DllImport("Crypt32.dll", SetLastError=true)]
$(if(-not $script:IsCoreCLR)
{
        '
        [SuppressUnmanagedCodeSecurity,
         ResourceExposure(ResourceScope.None),
         ReliabilityContract(Consistency.WillNotCorruptState, Cer.Success)]
        '
})
        private static extern void CertFreeCertificateChain(IntPtr handle);
    }

    public class Win32Helpers
    {
        [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
        public extern static
        bool CertVerifyCertificateChainPolicy(
            [In]     IntPtr                       pszPolicyOID,
            [In]     $SafeX509ChainHandleClassName  pChainContext,
            [In]     ref CERT_CHAIN_POLICY_PARA   pPolicyPara,
            [In,Out] ref CERT_CHAIN_POLICY_STATUS pPolicyStatus);

        [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
        public static extern
        $SafeX509ChainHandleClassName CertDuplicateCertificateChain(
            [In]     IntPtr pChainContext);

$(if($script:IsSafeX509ChainHandleAvailable)
{
@"
        [DllImport("Crypt32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    $(if(-not $script:IsCoreCLR)
    {
    '
        [ResourceExposure(ResourceScope.None)]
    '
    })
        public static extern
        SafeX509ChainHandle CertDuplicateCertificateChain(
            [In]     SafeX509ChainHandle pChainContext);
"@
})

        public static bool IsMicrosoftCertificate([In] $SafeX509ChainHandleClassName pChainContext)
        {
            //-------------------------------------------------------------------------
            //  CERT_CHAIN_POLICY_MICROSOFT_ROOT
            //
            //  Checks if the last element of the first simple chain contains a
            //  Microsoft root public key. If it doesn't contain a Microsoft root
            //  public key, dwError is set to CERT_E_UNTRUSTEDROOT.
            //
            //  pPolicyPara is optional. However,
            //  MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG can be set in
            //  the dwFlags in pPolicyPara to also check for the Microsoft Test Roots.
            //
            //  MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG can be set
            //  in the dwFlags in pPolicyPara to check for the Microsoft root for
            //  application signing instead of the Microsoft product root. This flag
            //  explicitly checks for the application root only and cannot be combined
            //  with the test root flag.
            //
            //  MICROSOFT_ROOT_CERT_CHAIN_POLICY_DISABLE_FLIGHT_ROOT_FLAG can be set
            //  in the dwFlags in pPolicyPara to always disable the Flight root.
            //
            //  pvExtraPolicyPara and pvExtraPolicyStatus aren't used and must be set
            //  to NULL.
            //--------------------------------------------------------------------------
            const uint MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG       = 0x00010000;
            const uint MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG = 0x00020000;
            //const uint MICROSOFT_ROOT_CERT_CHAIN_POLICY_DISABLE_FLIGHT_ROOT_FLAG    = 0x00040000;

            CERT_CHAIN_POLICY_PARA PolicyPara = new CERT_CHAIN_POLICY_PARA(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_PARA)));
            CERT_CHAIN_POLICY_STATUS PolicyStatus = new CERT_CHAIN_POLICY_STATUS(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_STATUS)));
            int CERT_CHAIN_POLICY_MICROSOFT_ROOT = 7;

            PolicyPara.dwFlags = (uint) MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG;
            bool isMicrosoftRoot = false;

            if(CertVerifyCertificateChainPolicy(new IntPtr(CERT_CHAIN_POLICY_MICROSOFT_ROOT),
                                                pChainContext,
                                                ref PolicyPara,
                                                ref PolicyStatus))
            {
                isMicrosoftRoot = (PolicyStatus.dwError == 0);
            }

            // Also check for the Microsoft root for application signing if the Microsoft product root verification is unsuccessful.
            if(!isMicrosoftRoot)
            {
                // Some Microsoft modules can be signed with Microsoft Application Root instead of Microsoft Product Root,
                // So we need to use the MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG for the certificate verification.
                // MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG can not be used
                // with MICROSOFT_ROOT_CERT_CHAIN_POLICY_ENABLE_TEST_ROOT_FLAG,
                // so additional CertVerifyCertificateChainPolicy call is required to verify the given certificate is in Microsoft Application Root.
                //
                CERT_CHAIN_POLICY_PARA PolicyPara2 = new CERT_CHAIN_POLICY_PARA(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_PARA)));
                CERT_CHAIN_POLICY_STATUS PolicyStatus2 = new CERT_CHAIN_POLICY_STATUS(Marshal.SizeOf(typeof(CERT_CHAIN_POLICY_STATUS)));
                PolicyPara2.dwFlags = (uint) MICROSOFT_ROOT_CERT_CHAIN_POLICY_CHECK_APPLICATION_ROOT_FLAG;

                if(CertVerifyCertificateChainPolicy(new IntPtr(CERT_CHAIN_POLICY_MICROSOFT_ROOT),
                                                    pChainContext,
                                                    ref PolicyPara2,
                                                    ref PolicyStatus2))
                {
                    isMicrosoftRoot = (PolicyStatus2.dwError == 0);
                }
            }

            return isMicrosoftRoot;
        }
    }
}
"@

    try {
        $AddType_prams = @{
            TypeDefinition = $Win32HelpersSource
            Language       = 'CSharp'
            ErrorAction    = 'SilentlyContinue'
        }
        if ((-not $script:IsCoreCLR -or $script:IsNanoServer) -and $RequiredAssembliesForWin32Helpers) {
            $AddType_prams['ReferencedAssemblies'] = $RequiredAssembliesForWin32Helpers
        }
        Add-Type @AddType_prams
    }
    catch {
        Write-Warning -Message "Win32Helpers: $_"
    }
}

#endregion

# SIG # Begin signature block
# MIInNgYJKoZIhvcNAQcCoIInJzCCJyMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD7adv3jWYxde6H
# wOSx6V7IO/d9GT1L3K2snsbrLCWkjKCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# CisGAQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEID5M9+REl24bAgK8TiJX2c/78S1r
# QLDOiD6L+F8P6B9WMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBv
# AGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAE
# ggEADM4IR5NifuZHYxXSCNrZLMCfufmeUGE9iDDgh5OM2ZxTyxE+C0JEudnfU0WL
# ZPDSoWYlaLXBqcCz96SNaKDcEXXvABfXNJ6dt6pWII1gSnwM/EzY1KFbxWw8btKk
# Zi07YzQBT0HkCC3bfvdZlogcZz76IaBTBfw3NlKMTFZFLQ9M6Ht1tQRJe/Jc7J0I
# zxdySfjylklWw2XbBL/JW7H5eZHcuRbJAVAQ5PteNqmGQJGQf8KN8EPXBxyOX9Iu
# aX0iADe2+Gjc9jHzuZlk4qu9NjDb0wuRcTQ56AqxA2Ds80L4CN06esetvRFGTZ57
# oNIHf/sKmTyy+kciify2m154JqGCF5MwghePBgorBgEEAYI3AwMBMYIXfzCCF3sG
# CSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG
# 9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQC
# AQUABCA2VatUr43OWTqKjOkUMLPtnmKjQcKzjvmPkBsnpSYHHQIGavNK6zUlGBMy
# MDI2MTExMDIyMDU1Ny44ODdaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHp
# MIIHIDCCBQigAwIBAgITMwAAAiu7AFD/TTuaoQABAAACKzANBgkqhkiG9w0BAQsF
# ADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNjAyMTkxOTQwMTFa
# Fw0yNzA1MTcxOTQwMTFaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCX3mi6OD3syUqQm4QqgkrKPbcsK/Qx3fYctL8+VM1uOY3b
# ooi5GxwauTgQf6JFHITToxS7gjqKlK8OFLzL6UTl0jxEK5t6DuOcgJXdvutimoTl
# OS0C3kyITXBAXoj/gp6hRR9z6WRip1Ktkilb3dJXCjQqT9P2Cuujr+Vz8r+Z+jDl
# 09ji/ic/4G34r3mVwjs//Gnx9Pu31V8rXFicNiAzxpubawpbd8pqfzlWT2vnG3kF
# 9l6MiREbvJ3XHLUwHQsh0t/TrSFx/s/yCqpJWYJ6oClG70tvsFH0aRP8wB4cP/CF
# a2ILvk26i3OcJBl+pqKjHTSBy9mvwTPEDlnzco0Nt8R6pSPTXZgBsscHhoKfC0WQ
# mOzY2keXbAmRTcZMyXz5v/AJbmoI0y07Bazvt5NkXddG9TErQWwtsFyIKrElDgWf
# HeCoTu1wu2ciD3dK72z3ca2gzoEDxT2j9BXIUKaiTzTdQPRsAMaO3dU0zaGwMMlw
# tSJyDh14YEgZoUu5vS8MugMqdrNjphyL65yKhjpAWbhYkIHO/0uZju95tP8zZNqX
# IRh4tdfWHJPATn9r+cxkyuh2x0VLdfx1lmK9X3NjH0NtgAs5JB/wOlkyuudxmFTf
# WVyRrL37ispOZ8aPAFgvyR6cNTkGpkFo35JRjciNmZiU4qT9Uty+V5gudFk1jwID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFD4WjuQTUJbtbd3jmvZku0FZ2eU2MB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQDO/CKsciEM8kr1fqH4TlfT66ENoTjxXw810pyE
# q0PdrgLwfgT3x+1gz7CQHtUdevqMQ5qHyDLhm6pT911CYkGN+6g+MU7fMYTr6d3S
# xieJwBIoWkfR4g7SitGzMKU465KEYejfddoUgovC/xcRpaALO5p3/A248ByhJiMt
# tBQNDtsT/HaCFwRFCURby/f8c1kky8F8xkCXFz+/MtZ5d1lWFjwOI2geZHWq9Xih
# DOgee5nS2koo5V6n8XG220UTevVf+pgmpIH71XKDVIYTGGZJs6yPlfJ2aXqw1ME4
# NR6okNsY3P1M31H6DMYRfJGNBNep595kXGh3YzA3cCiyg+jmJ58h/fTvjngIpuUF
# fODpDjFx0ic1YoLANxhCF3RhS9qYM7K40NEhKshYuaAkIG2XBKYig3r/0/b0sjvj
# Bws55AYonMm3A8qcX/6k9Vfc0mv9dtonHuWGfA2b+qE2qpCnhzGbdDHq7iOSZEw0
# 1nNupAMf1c41k9IoTQ2z3iw6w4ZZoLOyg4TKMbp1krpT4trip/y30Cv5khyqCDNq
# aXQpBkOYON8LgtoQ3amVOX7ix5jdrnx/vUxTUSigXvrWdL7Uk8kpmS0zto2Toy7a
# T5oBzCTvfj9iJ/BN/E1vhFBkhJCvZ7PVvsMSnTTmkx2Fal2lVkztuAI44fD/uyLJ
# daMQSzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
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
# A1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQAJrD90
# ykHpo/0AGb7lmwvsCtqROaCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7p3JYDAiGA8yMDI2MTExMDE2NDgzMloY
# DzIwMjYxMTExMTY0ODMyWjBzMDkGCisGAQQBhFkKBAExKzApMAoCBQDunclgAgEA
# MAYCAQACAQ8wBwIBAAICExwwCgIFAO6fGuACAQAwNgYKKwYBBAGEWQoEAjEoMCYw
# DAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0B
# AQsFAAOCAQEAD3zzsuoky7iQx/rcT9NE7I+gvS7MABKXPAhb+777kDbe+lRvkUbr
# n2I76iAf3KM4vrbfEBYy/VcEnnu7YU2vxmEOBSqMnTHyKFBkavqDurTzCK+Y20To
# ULd4ovLBLZaNyNM6FBKvvTpVyR5YurdYvK9SpA9DG/CmFIc6Q4f1+TGCIVjYh52S
# WW0WB6oanXeWTF0ggppFvlMUtdXKY9j11F2H3530Eyg7obnGZq5SO5vDYKsyiEV1
# oEJyuOF3JZH/n/nOPQy/BhQ/t87LtmhbBtaoaKUn1O32Ch5KXkVq6yz/1jofvU4l
# 1dXRXnvvE4K9CQYZ97MaASvnVdtcsEZqeDGCBA0wggQJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAACK7sAUP9NO5qhAAEAAAIrMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEICD5KjzpxheKMU8y6sMxdU97beoGsEBISjPYM+lYNF0DMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgcg4j9D+QV+1gD4zY5j7UHHdqMEPr9YMC
# 09Pa8WS/blIwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAiu7AFD/TTuaoQABAAACKzAiBCC8Id/OpFTG6fIEjGPxHwC+oIWFPN1qlsZq
# IUzezRa2fzANBgkqhkiG9w0BAQsFAASCAgAHJvYwr2G1VGRLu2XrArarE8dTwqDT
# yvlpUhqJaLRBoNis5AiclUMidh9TjdfNu7AWEps/3GvosS30raCxyY+Pgl3zThKw
# ZF1/qrtda9OxtndT5EOEFjfx1I2D1YOvesDCitbxn99Ks5fOspI/XBV+sqyaUOfX
# x7XOmv9dqa9YpHGJ++2e0lYUm/h3g26D9imxHXKXwDSxNjU18ZnFgaYk+rFWedwK
# n543qryfNT3LAioyqvzjXaeWM3wLrl3W4ip2Rd4bogJ4aNKqKy+S+GfofikEe0tF
# Z3LSDYatGBBOK4fn2Pln4+5mQATRbph8rleTAqRPH2fBG+j+oPz8YTvCx8NsLg+Q
# Z25a2EP/xjWebAFramLVYHpftrnaRN9OmH3aK8jvWNgV4s2gGQ/TeZqwOJCcSB/M
# JOZTbcvxvPlVsFptVVvKckRhR0e4Dm4uS985zDckuXUNRgkc7aewQ5sshl3U7H70
# Mswh6c8D5dV07JzjCkAsX7N2j7XXhajr9RQq2SNeoidGCMBc2q4j1zZOgRFpJwiE
# ERIodqGKdrQwsvHWb36l3oV57YXLASNAJ7NKRz00deav1h1RHZW7XUT3Zm1mCjun
# ccbF9DKeJa3wPtcs/k2N2jQpjOCiICcUUcuW04wACjpz6oO6GxNQQqtJeIpWXlBL
# iLklFYqZLlkR8Q==
# SIG # End signature block
