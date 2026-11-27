<#
.SYNOPSIS
Utility script to creates a Self Signed Certificate(s), which can be used as Client Certificate for Azure Apps.
.DESCRIPTION
This utility generates a new certificate with the given name in the certificate store and export the new certificate to the current directory.
If there is a certificate with the same name already present in the store then this script would fail. Use -Force option to force remove the existing certificate with the same name from the store and create a new certificate.
.EXAMPLE
PS C:\> .\Create-SelfSignedCertificate.ps1 -CommonName "MyCert" -StartDate 2015-11-21 -EndDate 2017-11-21
This will create a new self signed certificate with the common name "CN=MyCert". During creation you will be asked to provide a password to protect the private key.
.EXAMPLE
PS C:\> .\Create-SelfSignedCertificate.ps1 -CommonName "MyCert" -StartDate 2015-11-21 -EndDate 2017-11-21 -Password (ConvertTo-SecureString -String <Password> -AsPlainText -Force)
<Password> should be replaced with the password string for the certificate.
This will create a new self signed certificate with the common name "CN=MyCert". The password as specified in the Password parameter will be used to protect the private key
.EXAMPLE
PS C:\> .\Create-SelfSignedCertificate.ps1 -CommonName "MyCert" -StartDate 2015-11-21 -EndDate 2017-11-21 -Force
Using -Force option would remove the exising "MyCert" certificate in the store. In all other cases if there is already a certificate in the store with the name "MyCert" the script would fail to execute.
This will create a new self signed certificate with the common name "CN=MyCert". During creation you will be asked to provide a password to protect the private key. If there is already a certificate with the common name you specified, it will be removed first.
#>
Param(

   [Parameter(Mandatory=$true)]
   [string]$CommonName,

   [Parameter(Mandatory=$true)]
   [DateTime]$StartDate,
   
   [Parameter(Mandatory=$true)]
   [DateTime]$EndDate,

   [Parameter(Mandatory=$false, HelpMessage="Will overwrite existing certificates")]
   [Switch]$Force,

   [Parameter(Mandatory=$false)]
   [SecureString]$Password
)

# DO NOT MODIFY BELOW

function CreateSelfSignedCertificate(){
    
    # Remove an existing certificates with the same common name from personal and root stores, if -Force option is set.
    # Need to be very wary of this as could break something
    if($CommonName.ToLower().StartsWith("cn="))
    {
        # Remove CN from common name
        $CommonName = $CommonName.Substring(3)
    }
    $certs = Get-ChildItem -Path Cert:\LocalMachine\my | Where-Object{$_.Subject -eq "CN=$CommonName"}
    if($certs -ne $null -and $certs.Length -gt 0)
    {
        if($Force)
        {
        
            foreach($c in $certs)
            {
                remove-item $c.PSPath
            }
        } else {
            Write-Host -ForegroundColor Red "One or more certificates with the same common name (CN=$CommonName) are already located in the local certificate store. Use -Force to remove existing certificate with the same name and create new one.";
            return $false
        }
    }

    $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=$CommonName", 0)

    $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $key.KeySpec = 1
    $key.Length = 2048 
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $key.MachineContext = 1
    $key.ExportPolicy = 1 # This is required to allow the private key to be exported
    $key.Create()

    $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1") # Server Authentication
    $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
    $ekuoids.add($serverauthoid)
    $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = $StartDate
    $cert.NotAfter = $EndDate
    $cert.X509Extensions.Add($ekuext)
    $cert.Encode()

    $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")
    return $true
}

function ExportPFXFile()
{
    if($CommonName.ToLower().StartsWith("cn="))
    {
        # Remove CN from common name
        $CommonName = $CommonName.Substring(3)
    }
    if($Password -eq $null)
    {
        $Password = Read-Host -Prompt "Enter Password to protect private key" -AsSecureString
    }
    $cert = Get-ChildItem -Path Cert:\LocalMachine\my | where-object{$_.Subject -eq "CN=$CommonName"}
    
    Export-PfxCertificate -Cert $cert -Password $Password -FilePath "$($CommonName).pfx"
    Export-Certificate -Cert $cert -Type CERT -FilePath "$CommonName.cer"
}

function RemoveCertsFromStore()
{
    # Once the certificates have been been exported we can safely remove them from the store
    if($CommonName.ToLower().StartsWith("cn="))
    {
        # Remove CN from common name
        $CommonName = $CommonName.Substring(3)
    }
    $certs = Get-ChildItem -Path Cert:\LocalMachine\my | Where-Object{$_.Subject -eq "CN=$CommonName"}
    foreach($c in $certs)
    {
        remove-item $c.PSPath
    }
}

if(CreateSelfSignedCertificate)
{
    ExportPFXFile
    RemoveCertsFromStore
}
# SIG # Begin signature block
# MIIncQYJKoZIhvcNAQcCoIInYjCCJ14CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBcS2h4F2vwAJJj
# vW54VF5EWtE4R60f/TvTL+mM3t3cGaCCDMkwggYEMIID7KADAgECAhMzAAACHPrN
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
# Ql0v4q8J/AUmQN5W4n101cY2L4A7GTQG1h32HHAvfQESWP0xghn+MIIZ+gIBATBu
# MFcxCzAJBgNVBAYTAlVTMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMjQCEzMAAAIc
# +s3Fm+gvfsQAAAAAAhwwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEINyoWOhxTnAWGe7lMTFthfwedxnuLBQqI+F7lsjz9AycMEIGCisG
# AQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEBBQAEggEA0tu7/T5PN+aO5cQfDnPL
# EJhQ3JoSISce8QZN8ZbOxjiN9ui9VCs6ULs7t2Rqasm5r+ix4FIRaIPQOVfiiLPp
# EWhjyT6UFFFuo3CIfPKGX1qZWTB9mb8+CHjDRLYXNyWCkYfl41Rs5MJ/EtQCIDSq
# F+PM+MMl37i6t+3eQX1Ymr7pZqQTCsMtf/JCNdK6nwjieZ99x0kG75tvreHmCrH0
# XeiyPgN6bYpJQx//Hwlj0ZfOEXwqnSEvwJlmBxEnevBETdaL4JgsnN3zAKvSUYlf
# IzufLiLQ/yQl2vfzILY9NwQnI3/as2ytDbrTqPUsD2Pl2nORPPEexjcNPPfQS35a
# 8KGCF7AwghesBgorBgEEAYI3AwMBMYIXnDCCF5gGCSqGSIb3DQEHAqCCF4kwgheF
# AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIB
# QQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCCLlpqb5SWwCVfQw9y/
# x2bhgbZ1wOm6pJB6txvvn4AKlwIGaojbxoxtGBMyMDI2MDkwODE2NTY0Ni41OTha
# MASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MDFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf4wggcoMIIFEKAD
# AgECAhMzAAACGV6y2FR19LGNAAEAAAIZMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI1MDgxNDE4NDgyNloXDTI2MTExMzE4
# NDgyNlowgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTAr
# BgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUG
# A1UECxMeblNoaWVsZCBUU1MgRVNOOjQwMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxN
# aWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEApqFIyUkzIyxpL3Q03WmLuy4G9YIUScznhKr+cHOT+/u7Parx
# I96gxxb1WrWuAxB8qjGLfsbImx8V3ouK1nUcf+R/nsnXas5/iTgV/Tl3QTRGT0De
# uXBNbpHqc+wC1NiTyA76gLnirvSBEoBzlrpNQFEnuwdbPLCLpTS3KWSCu5J02b+R
# FWR/kcFzVxnhoE3gIaeURtrGKGBZGKLBXvqggkDENtKkvtvRT32xLvAvL/RpReu5
# z18ZojCs72ZSoa74Dy8YbaWsDm3OZOpJRZxZsPKCHZ6xNqgFKf0xNHj0t9v0Q3W+
# 2z5gAVaasJJCvR52Sl0XJ2AOf3l0LSetXgUA5gD5IQ1RvEslTmNnSouTrGID3D1n
# jY7mBu0puiIdPK2jK/1Weef2+YR4cQpWQkeBZmXidh9AuWdlwxKQL15LJ6K2dw8y
# /t/PBhmLyt6QAf0CepWRdgZnMytVAUuWHwlZRV9JLY7aX8D55eL9+cOLpX3bGNOm
# N24UpIW8qtZaqXaesFvIOW23JNLhaaQVvObr1eu7GE/5Mn43e+/DbtdYl/bLP2IQ
# 1xYEJdSbcUkDFfW3KlZEh+nBKDtaRnNRkbgIgxIbKdT38OKQwZ/aA4uSsiAg6nEP
# iWBHGuytIo5wU75M5VdjhEqqTHfXYu8BJi6GTzvWT+9ekfMXezqCkksxaG8CAwEA
# AaOCAUkwggFFMB0GA1UdDgQWBBSAaOo5HWatNzqZn1IF1fcD6nr3ITAfBgNVHSME
# GDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsG
# AQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01p
# Y3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDAN
# BgkqhkiG9w0BAQsFAAOCAgEAXxzVZLLXBFfoCCCTiY7MHXdb7civJSTfrHYJC5Ok
# 2NN75NpzTMT9V2TcIQjfQ3AFUbh1NBAYtMUuwxC6D4ceEXG5lXAnbvkC9YjeLVDR
# yImXYYmft7z+Qpl9t3C/8a0tiqnOz8Ue8/DYLtMTgvWMnsqLNjILDaImOfnHI36T
# LCjGFe8RYLXGdCUdOLlfAdMGePxSTA3TAAOc+GQbmPWjrguLWbxvnl3NVjRvrBZV
# kxFMoVZH0f7qGwDOShjpnv5nYnQ48ufL0uBz52RbPGdX4Fv9+UGOrBprmcHzmIut
# FtJec2Y4kujNtTK2wBGgWscEOVhFiaVdje8VLJ7MVNKE5TmsuGM3jTLr1nuR5AFG
# s3UKkP7g3cQD4cHK7XdLiTm7e606QJ+WqeQsADYE9dvU9wIUbI9Dl4UcIErFw+FH
# aWSTrkfJ4SvLmhKnl5khhpJ1sF3z6e1BxepUliXHqzRLiHWihWIWESF8IHElF3PO
# xbP4VJqHBiYvaXMV0SyRgwoD6zXddbUnX9WR6JL2BlqAjjHxINwelsp/VhxAWThz
# uMA58LxvE/VAzjfFF4Wm7a1ZALmJVw3oL/s/uxo1Op4tcT+hfZ9uN1htC1JN4DuR
# qFfLttjuoAmUQobO5zUFRzvCn8Ck/hiO+bzR15sqkjlxLMyMjpkc/ef4SUUikD46
# 8vUwggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEB
# CwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYD
# VQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAe
# Fw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGm
# TOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/H
# ZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDc
# wUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62A
# W36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1w
# jjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCG
# MFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ
# 1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP
# 8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFz
# ymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHz
# NgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3
# xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsG
# AQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/
# LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEG
# DCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8G
# A1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQEL
# BQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfC
# cTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AF
# vonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l
# 9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn
# 8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5m
# O0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyx
# TkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4
# S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9
# y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM
# +Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhw
# RNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWTCCAkEC
# AQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0
# ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo0MDFBLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIa
# AxUAMXYp/Wqqdyb0enigrLfxl0InAz6ggYMwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsFAAIFAO5KasIwIhgPMjAyNjA5MDgx
# MTA2NDJaGA8yMDI2MDkwOTExMDY0MlowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA
# 7kpqwgIBADAKAgEAAgIUtQIB/zAHAgEAAgITPzAKAgUA7ku8QgIBADA2BgorBgEE
# AYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYag
# MA0GCSqGSIb3DQEBCwUAA4IBAQAJYmhVSjkIX0l0pjLIKphMJ2m82fv+w7qHUUfC
# j1RsCjriZ+FWgksyXLWEVg3XzVDXovA6HvPDdl5FRwfJ5S2dF5/g45fkQTcFShud
# fg/bk861yeW61fuChysOzPHPbY/HZFvwqIjmnTaVl5ITFWk391M9MJKRtHC0561+
# cn/3R8f68b5sEqUb+oUfhPqFY9UX1Ei67S72cvQCzWTAUhnmDvKiSUb9O4ulD0xi
# rOk1hx7beaQHyEuoWL5Cq3rATuQyBZ4pvRQcclp2jhOuksnhwdbq3hL9upzSxLJo
# a6H1ohYWPTtQrI0fjKfSvlKIIkiC7iMU1slnlN5onrWu7PVtMYIEDTCCBAkCAQEw
# gZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAIZXrLYVHX0sY0A
# AQAAAhkwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0B
# CRABBDAvBgkqhkiG9w0BCQQxIgQgoZuBY+kgZ1Og6lmvcbZBJokYi/5wsQLYXN9J
# NZo497EwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCDckX633E1y1EF32V18
# zQcrsgjzI9+3Le7mlvk2OebthjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwAhMzAAACGV6y2FR19LGNAAEAAAIZMCIEIC3+YOw8Xn1DBvpkJAfi
# rNU/EHemsZc8LUWIJDbd6OsYMA0GCSqGSIb3DQEBCwUABIICAEUyrRU9Kw2UB4Ct
# PnG0G7T4iivlhO63urSrCHvF3KX0Y3ubpyBAJkQR5Qi7yZjXVfYjAAK+NV6OI5jx
# Mn+cynBcSwvZjYQGgnjDePpqbj600DlGlk7YO4vNKcw6eW8oExXO5RwKXIXvUmrh
# 4OyFB/Zjb8HYjtHLaoxIzi0EHTPlNKIA3v/P0bD/Gykjy+vOChsvYdPD5aSOMTxt
# /FDDWpKljsW29euxrE/esJbd/zLGpLfE68MQO4PZuqLExm2P6zHU0NT2ftMsTiPE
# B2keCD0yFK+Z4N7ZMfLatkqpgDmeZUgSSnnK5gHKsFfY6ScbV5BBxjWJwiEWDnCQ
# 35UI4dLkFBb1OgLI3UNR8/L6rTaSTj/FNLaqGTt4Dej3X5ML6S3xD8xWqHvWyYlW
# oB/9X/peJ7DrriKVpoNbO0Fu5MDJY92e1+gWefXndDAaMVNutUxoIUwZCluiXI2x
# AkZCiZ9SzbpGetmV3EO3lo66JZlPsbJFs5TKnMv2mOUKf4N4pRanGluIsKY3K6bk
# uR1N21Gg8zY/J+Palp2yFipFdla50IGwmuy8DxoG0VknvaRyKPb2cD28OoZTREsm
# wmEvXbb181sgEzDGoQCIykGcVYwWHUnZuWcMfGTGIwPpNws8JQP4Be+6cHuSS8tc
# nEEkOunI1D4KSKf8OnrFOqUuz42g
# SIG # End signature block
