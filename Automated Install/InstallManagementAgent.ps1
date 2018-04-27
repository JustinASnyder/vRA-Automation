Param (
    [string]$vaAddress = "",
    [string]$ServiceUserName = "",
    [string]$ServiceUserPassword = "",
    [string]$vaRootUserPassword = "",
    [string]$vaRootUserName = "root", 
    [string]$vaAddressCertThumbprint = "", 
    [string]$maInstallPath = "${env:ProgramFiles(x86)}" 
)

# The command parameters for Installing the Management Agent. 
# Parameter {0} - full path to the MA msi;
# Parameter {1} - full path to the MA install folder; 
# Parameter {2} - current datetime
# Parameter {3} - Address to the Management Endpoint on the Virtual Appliance
# Parameter {4} - Thumbprint of the Management Endpoint certificate, can be ommitted.
# Parameter {5} - User Name to be used for the Management Agent Service
# Parameter {6} - Password for the User Name
# Parameter {7} - User name to authenticate with the Virtual Appliance, defaults to root
# Parameter {8} - Password for thre User
$CommandParams = ' /i "{0}" /qn /norestart /Lvoicewarmup! "{1}\VMware\vCAC\Logs\ManagementAgentInstall-{2:yyyyMMdd-HHmm}.log" ADDLOCAL="ALL" INSTALLLOCATION="{1}\VMware\vCAC\Management Agent\" MANAGEMENT_ENDPOINT_ADDRESS="{3}" MANAGEMENT_ENDPOINT_THUMBPRINT="{4}" SERVICE_USER_NAME="{5}" SERVICE_USER_PASSWORD="{6}" VA_USER_NAME="{7}" VA_USER_PASSWORD="{8}"'

# Tries to download the MA msi file from the list of VAs. Returns the path to the file.
function DownloadMAInstaller($vaAddress)
{
    $downloadedFile = $null

    try
    {
        $downloadedFile = DownloadMA($vaAddress)
        Write-Host ("Downloaded Management Agent installer in '{0}'" -f $downloadedFile)
    }
    catch
    {
        Write-Host ("Unable to download Management Agent from VA '{0}'. `nError: {1}. `nDetails: {2}." -f $vaAddress, $_, $_.Exception)
        exit 1
    }

    return $downloadedFile
}

# Downloads the MA msi file from the specified VA. Returns the path to the file.
function DownloadMA($vaUrl)
{
    $destination = GetTempFileName("msi")
    $url = [System.Uri]$vaUrl
    $downloadUrl = New-Object System.Uri -ArgumentList $url, "/installer/vCAC-IaaSManagementAgent-Setup.msi"

    #allow TLS 1.2 for the download call
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    [Net.ServicePointManager]::ServerCertificateValidationCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
        $c = [System.Security.Cryptography.X509Certificates.X509Certificate2]$args[1]
        if ($vaAddressCertThumbprint -eq "")
        {
            Write-Host ("Virtual appliance certificate thumbprint: {0}" -f $c.Thumbprint)
            $global:vaThumbprint = $c.Thumbprint
        }
        else {
            $global:vaThumbprint = $vaAddressCertThumbprint
        }

        ($c.Thumbprint.ToString() -eq $global:vaThumbprint)
    }

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $destination)

    return $destination
}

# Returns a temporary file name with the specified extension
function GetTempFileName($extension)
{
    $fileName = [System.IO.Path]::GetRandomFileName()
    $fileName = [System.IO.Path]::ChangeExtension($fileName, $extension)
    return [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $fileName)

    #$fileName = [System.IO.Path]::GetRandomFileName()
    #$fileName = [System.IO.Path]::ChangeExtension($fileName, $extension)
    #return $fileName
}

# Downloads the new MA msi from the VA and installs the MA.
function InstallMA()
{
    $global:msi = DownloadMAInstaller $vaAddress

    if ($vaAddressCertThumbprint -eq "")
    {
        $vaAddressCertThumbprint = $global:vaThumbprint
    }

    $CommandParams = $CommandParams -f $global:msi, $maInstallPath, (Get-Date), $vaAddress, $vaAddressCertThumbprint, $ServiceUserName, $ServiceUserPassword, $vaRootUserName, $vaRootUserPassword

    $proc = Start-Process -FilePath $Env:SystemRoot\system32\msiexec.exe -ArgumentList $CommandParams -Wait -Passthru
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    if (($exitCode -ne 0) -and ($exitCode -ne 3010))
    {
        throw ("Management Agent installation failed with error code: {0}" -f $exitCode)
    }
}

# Install the Management Agent
try
{
    if ($vaAddress -eq "")
    {
        Write-Host ("Missing required parameter vaAddress. Enter Virtual Appliance address in the format https://url:5480")
        #$vaAddress = Read-Host
        exit 1
    }

    if ($vaRootUserPassword -eq "")
    {
        Write-Host ("Missing required parameter vaRootUserPassword ")
        #$vaRootUserPassword = Read-Host
        exit 1
    }

    if ($ServiceUserName -eq "")
    {
        Write-Host ("Missing required parameter ServiceUserName")
        #$vaRootUserPassword = Read-Host
        exit 1
    }

    if ($ServiceUserPassword -eq "")
    {
        Write-Host ("Missing required parameter ServiceUserPassword")
        #$vaRootUserPassword = Read-Host
        exit 1
    }

    if ($maInstallPath -eq "")
    {
        Write-Host ("Missing required parameter maInstallPath, or default value retrieval failed.")
        #$vaRootUserPassword = Read-Host
        exit 1
    }

    # get PS version
    $ver = $PsVersionTable.psversion.major

    If ($ver -le 2)
    {
        Write-Host ("PowerShell version should be 3.0 or above in order to be able to download Management Agent installation package.")
        exit 1
    }

    if (-not (Test-Path ("{0}\VMware\vCAC\Logs\" -f $maInstallPath)))
    {
        New-Item ("{0}\VMware\vCAC\Logs\" -f $maInstallPath) -type directory
    }

    #Download installer and install MA
    InstallMA

    Write-Host "Successfuly installed Management Agent"
    exit 0
}
catch
{
    $message = "Management Agent installation failed. `nError: {0}. `nDetails: {1}" -f $_, $_.Exception
    Write-Host $message
    exit 1
}
finally
{
    # Remove the downloaded MSI
    if (-not [string]::IsNullOrEmpty($global:msi) -and (Test-Path $global:msi))
    {
        #Remove-Item $global:msi -Confirm:$false
    }
}
# SIG # Begin signature block
# MIIebgYJKoZIhvcNAQcCoIIeXzCCHlsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUl4KMegaNOX/UsAJNeh4n8rMY
# YoSgghlLMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUCMIID6qADAgECAhBZBAlX8ghDMCulKqH2q87vMA0GCSqGSIb3DQEBBQUAMIG0
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBh
# dCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVW
# ZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAyMDEwIENBMB4XDTE2MTEwMjAw
# MDAwMFoXDTE5MTIyMTIzNTk1OVowZDELMAkGA1UEBhMCVVMxEzARBgNVBAgMCkNh
# bGlmb3JuaWExEjAQBgNVBAcMCVBhbG8gQWx0bzEVMBMGA1UECgwMVk13YXJlLCBJ
# bmMuMRUwEwYDVQQDDAxWTXdhcmUsIEluYy4wggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDfor5Ckbvs5aMDHKYL9yTy5l8JG4X6FqSsq4+9UjBbqFeGUu3q
# gcKCvOhsa0pSiNrsJdZfl7TjvjFRpL7pTmSSg/nn5nFwgd6FkQ8GA6iJMfFpnQpQ
# MnrEoCIQQ2otyARWlJqBHa4/vrH+ZzJJ5NgZLfL1rS95q6J7ddQmE6UBzQHrMLEu
# iKvwjpN6nH/szuhE7x7ZnAsrJJIr9dmwlBtTyUHYIln/RZD6SfhXRObbxTajd8NT
# ycRUXhDf7BT8QmFYgWL73XiErVwH2apkj/HYntrvu27cwWsgrQ5RY/YeSNLiNIh4
# SMjb5J6cNs865oTiOV6Q+VDxnKWPS7QeqJQRAgMBAAGjggFdMIIBWTAJBgNVHRME
# AjAAMA4GA1UdDwEB/wQEAwIHgDArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8vc2Yu
# c3ltY2IuY29tL3NmLmNybDBhBgNVHSAEWjBYMFYGBmeBDAEEATBMMCMGCCsGAQUF
# BwIBFhdodHRwczovL2Quc3ltY2IuY29tL2NwczAlBggrBgEFBQcCAjAZDBdodHRw
# czovL2Quc3ltY2IuY29tL3JwYTATBgNVHSUEDDAKBggrBgEFBQcDAzBXBggrBgEF
# BQcBAQRLMEkwHwYIKwYBBQUHMAGGE2h0dHA6Ly9zZi5zeW1jZC5jb20wJgYIKwYB
# BQUHMAKGGmh0dHA6Ly9zZi5zeW1jYi5jb20vc2YuY3J0MB8GA1UdIwQYMBaAFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMB0GA1UdDgQWBBSHLwm3dovJcZZELj+JJRBe7RAr
# qDANBgkqhkiG9w0BAQUFAAOCAQEAkyzWYWPDu7EaCyk4LVRhdXE1vDXKEdW200Y3
# bL6M5Mo0qDIw2/HvER9dlLkyf5ov7maxhv8lAsJcTVyd/JApwM+KU51Cbqc9DYgr
# kEB7Joc8Jaq84ahe4AVW5Ac+1wjI1XnONnWh8Z6hcWd7i45Xt7Y97agPWdi8+q1M
# 2YxJEIZvJ2Y04AwWjUQf5RmV5PRU/4SG6GRavrhs/kmrkE/MzL17h7y3gpJBWttu
# bTRwBldI8XWT3P5K1ERcSZtg8mqpQ4Jf8g7Im3VFKY+4ZPupJaM9oUoZU4vvmDyz
# VdyryH3saay+ddId9TeepqeDjyYmN8QsD1lpzhsA09P9zSfrnzCCBZowggOCoAMC
# AQICCmEZk+QAAAAAABwwDQYJKoZIhvcNAQEFBQAwfzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEpMCcGA1UEAxMgTWljcm9zb2Z0IENvZGUgVmVy
# aWZpY2F0aW9uIFJvb3QwHhcNMTEwMjIyMTkyNTE3WhcNMjEwMjIyMTkzNTE3WjCB
# yjELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL
# ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJp
# U2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxW
# ZXJpU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0
# aG9yaXR5IC0gRzUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvJAgI
# KXo1nmAMqudLO07cfLw8RRy7K+D+KQL5VwijZIUVJ/XxrcgxiV0i6CqqpkKzj/i5
# Vbext0uz/o9+B1fs70PbZmIVYc9gDaTY3vjgw2IIPVQT60nKWVSFJuUrjxuf6/Wh
# kcIzSdhDY2pSS9KP6HBRTdGJaXvHcPaz3BJ023tdS1bTlr8Vd6Gw9KIl8q8ckmcY
# 5fQGBO+QueQA5N06tRn/Arr0PO7gi+s3i+z016zy9vA9r911kTMZHRxAy3QkGSGT
# 2RT+rCpSx4/VBEnkjWNHiDxpg8v+R70rfk/Fla4OndTRQ8Bnc+MUCH7lP59zuDMK
# z10/NIeWiu5T6CUVAgMBAAGjgcswgcgwEQYDVR0gBAowCDAGBgRVHSAAMA8GA1Ud
# EwEB/wQFMAMBAf8wCwYDVR0PBAQDAgGGMB0GA1UdDgQWBBR/02Wnwt3su/AwCfND
# OfoCrzMxMzAfBgNVHSMEGDAWgBRi+wohW39DbhHaCVRQa/XSlnHxnjBVBgNVHR8E
# TjBMMEqgSKBGhkRodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9NaWNyb3NvZnRDb2RlVmVyaWZSb290LmNybDANBgkqhkiG9w0BAQUFAAOC
# AgEAgSqCFow0ZyvlA+s0e4yio1CK9FWG8R6Mjq597gMZznKVGEitYhH9IP0/RwYB
# WuLgb4wVLE48alBsCzajz3oNnEK8XPgZ1WDjaebiI0FnjGiDdiuPk6MqtX++Wfup
# ybImj8qi84IbmD6RlSeXhmHuW10Ha82GqOJlgKjiFeKyviMFaroM80eTTaykjAd5
# OcBhEjoFDYmj7J9XiYT77Mp8R2YUkdi2Dxld5rhKrLxHyHFDluYyIKXcd4b9POOL
# cdt7mwP8tx0yZOsWUqBDo/ourVmSTnzH8jNCSDhROnw4xxskIihAHhpGHxfbGPfw
# JzVsuGPZzblkXSulXu/GKbTyx/ghzAS6V/0BtqvGZ/nn05l/9PUi+nL1/f86HEI6
# ofmAGKXujRzUZp5FAf6q7v/7F48w9/HNKcWd7LXVSQA9hbjLu5M6J2pJwDCuZsn3
# Iygydvmkg1bISM5alqqgzAzEf7SOl69t41Qnw5+GwNbkcwiXBdvQVGJeA0jC1Z9/
# p2aM0J2wT9TTmF9Lesl/silS0BKAxw9Uth5nzcagbBEDhNNIdecq/rA7bgo6pmt2
# mQWj8XdoYTMURwb8U39SvZIUXEokameMr42QqtD2eSEbkyZ8w84evYg4kq5Fxhlq
# SVCzBfiuWTeKaiUDlLFZgVDouoOAtyM19Ha5Zx1ZGK0gjZQwggYKMIIE8qADAgEC
# AhBSAOWqJVb8GobtlsnUSzPHMA0GCSqGSIb3DQEBBQUAMIHKMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRy
# dXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0g
# Rm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNz
# IDMgUHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTAe
# Fw0xMDAyMDgwMDAwMDBaFw0yMDAyMDcyMzU5NTlaMIG0MQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0
# IE5ldHdvcmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBhdCBodHRwczovL3d3dy52
# ZXJpc2lnbi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVWZXJpU2lnbiBDbGFzcyAz
# IENvZGUgU2lnbmluZyAyMDEwIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEA9SNLXqXXirsy6dRX9+/kxyZ+rRmY/qidfZT2NmsQ13WBMH8EaH/LK3Ue
# zR0IjN9plKc3o5x7gOCZ4e43TV/OOxTuhtTQ9Sc1vCULOKeMY50Xowilq7D7zWpi
# gkzVIdob2fHjhDuKKk+FW5ABT8mndhB/JwN8vq5+fcHd+QW8G0icaefApDw8QQA+
# 35blxeSUcdZVAccAJkpAPLWhJqkMp22AjpAle8+/PxzrL5b65Yd3xrVWsno7VDBT
# G99iNP8e0fRakyiF5UwXTn5b/aSTmX/fze+kde/vFfZH5/gZctguNBqmtKdMfr27
# Tww9V/Ew1qY2jtaAdtcZLqXNfjQtiQIDAQABo4IB/jCCAfowEgYDVR0TAQH/BAgw
# BgEB/wIBADBwBgNVHSAEaTBnMGUGC2CGSAGG+EUBBxcDMFYwKAYIKwYBBQUHAgEW
# HGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9jcHMwKgYIKwYBBQUHAgIwHhocaHR0
# cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYTAOBgNVHQ8BAf8EBAMCAQYwbQYIKwYB
# BQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2UvZ2lmMCEwHzAHBgUrDgMCGgQUj+XT
# GoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDovL2xvZ28udmVyaXNpZ24uY29tL3Zz
# bG9nby5naWYwNAYDVR0fBC0wKzApoCegJYYjaHR0cDovL2NybC52ZXJpc2lnbi5j
# b20vcGNhMy1nNS5jcmwwNAYIKwYBBQUHAQEEKDAmMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC52ZXJpc2lnbi5jb20wHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUF
# BwMDMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBWZXJpU2lnbk1QS0ktMi04MB0G
# A1UdDgQWBBTPmanqeyb0S8mOj9fwBSbv49KnnTAfBgNVHSMEGDAWgBR/02Wnwt3s
# u/AwCfNDOfoCrzMxMzANBgkqhkiG9w0BAQUFAAOCAQEAViLmNKTEYctIuQGtVqhk
# D9mMkcS7zAzlrXqgIn/fRzhKLWzRf3EafOxwqbHwT+QPDFP6FV7+dJhJJIWBJhyR
# FEewTGOMu6E01MZF6A2FJnMD0KmMZG3ccZLmRQVgFVlROfxYFGv+1KTteWsIDEFy
# 5zciBgm+I+k/RJoe6WGdzLGQXPw90o2sQj1lNtS0PUAoj5sQzyMmzEsgy5AfXYxM
# NMo82OU31m+lIL006ybZrg3nxZr3obQhkTNvhuhYuyV8dA5Y/nUbYz/OMXybjxuW
# nsVTdoRbnK2R+qztk7pdyCFTwoJTY68SDVCHERs9VFKWiiycPZIaCJoFLseTpUiR
# 0zGCBI0wggSJAgEBMIHJMIG0MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNp
# Z24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOzA5BgNV
# BAsTMlRlcm1zIG9mIHVzZSBhdCBodHRwczovL3d3dy52ZXJpc2lnbi5jb20vcnBh
# IChjKTEwMS4wLAYDVQQDEyVWZXJpU2lnbiBDbGFzcyAzIENvZGUgU2lnbmluZyAy
# MDEwIENBAhBZBAlX8ghDMCulKqH2q87vMAkGBSsOAwIaBQCggYowGQYJKoZIhvcN
# AQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
# IwYJKoZIhvcNAQkEMRYEFD5DZscThRLv3uLIOcu1oqFesYz6MCoGCisGAQQBgjcC
# AQwxHDAaoRiAFmh0dHA6Ly93d3cudm13YXJlLmNvbS8wDQYJKoZIhvcNAQEBBQAE
# ggEAWW9MIqRRRl6TK3kFOq3h2s9e3D81TlOucg3FKU1OnSyhmeI28fQSR/kgwgRO
# RHvDEam/lnHlrC7QiJKeyB91oTRqpMnGOLuQaZVczHjepxFP5CeV5gVyxXx5Hddz
# NAE2+eLRpgPHsulyVHNx2k6u8NJNZwumga8qh3V8Z1cknAbQb/yneQVPK+YUf23Y
# ruX1ll1avmmZDhXYxWWaoR41+gGUjWxPG6I9qZ+lnOAZcO7yHpMtN0DCNa01VI09
# sN4a6Msv11GXEJo9Jc8w5PKweOPUN+aIMkAFCzCjW6d9vb6i+IjI3CmbNeCc1IMF
# NDGnmirOGyxz4gVHe3JtidMXK6GCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIB
# ATByMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlv
# bjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAt
# IEcyAhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xODA0MDUwODA0MTNaMCMGCSqG
# SIb3DQEJBDEWBBRFGFhwUlgm9l80UrwYLwrAj+052jANBgkqhkiG9w0BAQEFAASC
# AQAWYLSeY62Tm1rvNL9A/Mha/U1xnYJeKHyU5+fOG6lZeoImx6/D9CF/Jyek2JHh
# rcJNSz0IP1KmJVvFBd7jn5rz8Bwd9923+w7KrePwCNGIuD082gnmHT4UMp5V8cgQ
# TBfptafG7wRVPEIRujqhsFWWbceUEzXPKsOAFAe9ujwt/dbvmrBH50kBAQjO6Ziz
# Sj9LT9ktWwnKD0UNIbOWCIyjuEA2zTmkVZpqka2uZrGaaiCAC6o/uMOoTCv1YesF
# 1k3dBerRgafjHkhcJypDZhmRotRmnTStR2GbwNlTNFbh4yFY7sMfwYKQPEHddnLr
# lKdprr3hziqqtutcK7wFCaxV
# SIG # End signature block
