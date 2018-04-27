#========================================================================================
#  vRA-Automated-Install.ps1
#  Author:  Justin Snyder
#  Website: https://www.ltx.systems/
#  Date:    04/27/2018
#  Purpose: This script has the core logic for an automated minimal configuration deployment
#           of vRA.  This script can be used for 7.2, 7.3, or 7.4.  
#           The script must copy a Management agent installer script to the IaaS Server.
#           The version of the management agent installer script varies from 7.2/7.3 to
#           7.4.  Be sure to use the right version of that script.
#  Use:     Place the main script, deploymentVariables-XXX.ps1 script, and the 
#           InstallManagementAgent.ps1 script into the same directory.  Connect-VIServer to the 
#           vCenter Server where deployment will occur, and run the vRA-Automated-Install.ps1
#           script.  Some Items relating to prompts can be configured below to make this 
#           interactive or silent.
#========================================================================================

#============Configurable Items=================

#if false, won't prompt for any values
$PromptForParams = $false

#if false, won't prompt for any values that have defaults set
$PromptIfAlreadySet = $false

#if true, will always prompt for passwords and ignore values, even if $PromptForParams is false
$AlwaysPromptForPasswords = $false

#-------------- Includes ------------------
#-- Change this file for configurable 
#-- values for different installations
#-- Contents can be changed, or
#-- separate versions created for different
#-- sites and configs
#------------------------------------------

#Include Deployment Variables - Controls various settings about OVF and VM deployment
. .\deploymentVariables-Template.ps1



#==================Non-Configurable====================

# -------------------------------------
# ---  DO NOT EDIT BELOW THIS POINT ---
# -------------------------------------

#new VMs to be created
$iaasVM = $null
$vraVAVM = $null

#files to copy to IaaS Guest
$iaasFiles = @(
    "InstallManagementAgent.ps1")


#vRA VA Silent Install Answer File Template Name
$answerFileTemplate = "ha.properties.template"

#File to be generated with answers; will be transferred to the VA for install
$vraInstallAnswerFile = "ha-generated.properties"

$DisplayPrompts = @{
    "vRASourceOVA" = "vRA Appliance OVA Source File";
    "vRAVADisplayName" = "vRA Appliance vSphere Display Name";
    "vRAVAHostname" = "vRA Appliance Fully Qualified Host Name";
    "vRAVAMemoryMB" = "vRA Appliance Memory in MB";
    "vRAVANumCPUs" = "vRA Appliance Number of vCPUs";
    "vRAVANetwork" = "vRA Appliance NIC0 Network Name (i.e. PortGroup or dvPortGroup name)";
    "vRAVATargetDatastore" = "vRA Appliance Target Datastore";
    "vRAVATargetHost" = "vRA Appliance Target vSphere Host";
    "vRAVATargetFolder" = "vRA Appliance Target VM Folder";
    "vRAVARootPassword" = "vRA Appliance Root Password";
    "vRAVASSHEnabled" = "Enable SSH on vRA Appliance?  Only set this in the defaults by changing the script!";
    "vRAVAGateway" = "vRA Appliance IPv4 Default Gateway";
    "vRAVADomain" = "vRA Appliance Default Domain Suffix";
    "vRAVASearchPath" = "vRA Appliance Domain Search Path";
    "vRAVADNSServers" = "vRA Appliance DNS Server List (comma separated)";
    "vRAVAIPAddress" = "vRA Appliance IPv4 Address";
    "vRAVASubnetMask" = "vRA Appliance IPv4 Subnet Mask";

    "IaaSVMToClone" = "Base VM or Template to Clone for the IaaS Server";
    "IaaSVMDisplayName" = "IaaS VM vSphere Display Name";
    "IaaSVMTargetDatastore" = "IaaS VM Target Datastore";
    "IaaSVMTargetHost" = "IaaS VM Target vSphere Host";
    "IaaSVMTargetFolder" = "IaaS VM Target VM Folder";
    "IaaSVMHostname" = "IaaS VM Fully Qualified Host Name";
    "IaaSVMMemoryMB" = "IaaS VM Memory in MB";
    "IaaSVMNumCPUs" = "IaaS VM Number of vCPUs";
    "IaaSVMNetwork" = "IaaS VM NIC0 Network Name (i.e. PortGroup or dvPortGroup name)";
    "IaaSVMDomainName" = "IaaS VM Domain Name (will be added to workgroup if none is specified)";
    "IaaSDomainUsername" = "Domain Username To Use When Joining Domain (leave blank if not joining domain)";
    "IaaSDomainPassword" = "Domain Password To Use When Joining Domain (leave blank if not joining doain)";
    "IaaSVMWorkgroupName" = "IaaS VM Workgroup (value will be ignored if Domain was specified)";
    "IaaSVMGateway" = "IaaS VM IPv4 Gateway";
    "IaaSVMIPAddress" = "IaaS VM Ipv4 Address";
    "IaaSVMSubnetMask" = "IaaS VM IPv4 Subnet Mask";
    "IaaSVMDNSServer" = "IaaS VM DNS Server";
    "IaaSVMDNSSuffix" = "IaaS VM DNS Suffix";
    "IaaSVMAdministratorPassword" = "IaaS VM Administrator Password";
    "IaaSAdministratorName" = "IaaS Administrator Full Name";
    "IaaSOrgName" = "IaaS Organization Name";
    "IaaSTimezone" = "IaaS Server Timezone (Eastern=035, Central=020, Mountain=010, Pacific=004, Alaska=003, Hawaii=002)";

    "IaaSServiceAccountUsername" = "Service Account For the vRA Services Running On The IaaS Server";
    "IaaSServiceAccountPassword" = "Service Account Password For The vRA Services Running On The IaaS Server";
}

$promptOrder = "vRASourceOVA,vRAVADisplayName,vRAVAHostname,vRAVATargetDatastore,vRAVATargetHost,vRAVATargetFolder,vRAVAMemoryMB,vRAVANumCPUs,vRAVANetwork,vRAVARootPassword,vRAVASSHEnabled,vRAVAGateway,"
$promptOrder += "vRAVADomain,vRAVASearchPath,vRAVADNSServers,vRAVAIPAddress,vRAVASubnetMask,"
$promptOrder += "IaaSVMToClone,IaaSVMDisplayName,IaaSVMTargetDatastore,IaaSVMTargetHost,IaaSVMTargetFolder,IaaSVMMemoryMB,IaaSVMNumCPUs,IaaSVMNetwork,IaaSVMHostname,"
$promptOrder += "IaaSVMDomainName,IaaSDomainUsername,IaaSDomainPassword,IaaSVMWorkgroupName,IaaSVMGateway,IaaSVMIPAddress,IaaSVMSubnetMask,IaaSVMDNSServer,IaaSVMAdministratorPassword,"
$promptOrder += "IaaSAdministratorName,IaaSOrgName,IaaSServiceAccountUsername,IaaSServiceAccountPassword"

if($PromptForParams -or $AlwaysPromptForPasswords)
{
    foreach($a in $promptOrder.Split(","))
    {
        $defaultSet = $false

        if($ScriptVariables.Get_Item($a) -ne "" -and $ScriptVariables.Get_Item($a) -ne $null)
        {
            $defaultSet = $true
        }
            
        if(($a.Contains("password") -or $a.Contains("Password")) -and ($AlwaysPromptForPasswords -or ($defaultSet -eq $false) -or ($PromptIfAlreadySet)))
        {
            $input = Read-Host -Prompt ($DisplayPrompts.Get_Item($a) + " ") -AsSecureString
            
            if($input -ne "") 
            {
                $ScriptVariables.Set_Item($a, $input)
            }
        }
        elseif($PromptForParams -and (($defaultSet -eq $false) -or ($PromptIfAlreadySet)))
        {
            $input = Read-Host -Prompt ($DisplayPrompts.Get_Item($a) + " [" + $ScriptVariables.Get_Item($a) + "]")
            
            if($input -ne "") 
            {
                $ScriptVariables.Set_Item($a, $input)
            }
        }

    }
}

foreach($a in $promptOrder.Split(","))
{
    if(($a.Contains("password") -or $a.Contains("Password")))
    {
        Write-Output ("${a}: **********")
    }
    else
    {
        Write-Output ("${a}: " + $ScriptVariables.Get_Item($a))
    }
}

function Create-AnswerFile
{

    Write-Host "==========   Creating Answer File   ==========" -ForegroundColor Yellow

    $templateFileContent = Get-Content $answerFileTemplate

    foreach($key in $answerFileValues.Keys)
    {
        $val = $answerFileValues.Get_Item("$key")

        $templateFileContent = $templateFileContent.Replace("`$$key", $val)
    }

    Set-Content -Path $vraInstallAnswerFile -Value ([byte[]][char[]] "$templateFileContent") -Encoding Byte

    Write-Host "    Complete.  Contents written to $vraInstallAnswerFile"
}

function Deploy-vRAAppliance
{

    Write-Host "==========   Starting vRA VA Deployment   ==========" -ForegroundColor Yellow
    
    $targetHost = $ScriptVariables.Get_Item("vRAVATargetHost")
    $displayName = $ScriptVariables.Get_Item("vRAVADisplayName")
    $datastore = $ScriptVariables.Get_Item("vRAVATargetDatastore")
    $sourceOVA = $ScriptVariables.Get_Item("vRASourceOVA")
    $memory = $ScriptVariables.Get_Item("vRAVAMemoryMB")
    $numCPU = $ScriptVariables.Get_Item("vRAVANumCPUs")
    $network = $ScriptVariables.Get_Item("vRAVANetwork")
    $folder = Get-Folder $ScriptVariables.Get_Item("vRAVATargetFolder")
    
    
    $ovfProperties= @{
       "varoot-password" = $ScriptVariables.Get_Item("vRAVARootPassword");
       "va-ssh-enabled" = $true;
       "vami.hostname" = $ScriptVariables.Get_Item("vRAVAHostname");
       "vami.gateway.VMware_vRealize_Appliance" = $ScriptVariables.Get_Item("vRAVAGateway");
       "vami.domain.VMware_vRealize_Appliance" = $ScriptVariables.Get_Item("vRAVADomain");
       "vami.searchpath.VMware_vRealize_Appliance" = $ScriptVariables.Get_Item("vRAVASearchPath");
       "vami.DNS.VMware_vRealize_Appliance" = $ScriptVariables.Get_Item("vRAVADNSServers");
       "vami.ip0.VMware_vRealize_Appliance" = $ScriptVariables.Get_Item("vRAVAIPAddress");
       "vami.netmask0.VMware_vRealize_Appliance" = $ScriptVariables.Get_Item("vRAVASubnetMask");
    }

    Write-Host "--- vRA VA OVF Properties ---" -ForegroundColor Green
    foreach ($k in $ovfProperties.Keys)
    {
        if($k -ne "varoot-password") 
        {
            Write-Host ("    " + $k + ": " + $ovfProperties.Get_Item($k)) -ForegroundColor Green
        }
        else
        {
            Write-Host ("    " + $k + ": ****") -ForegroundColor Green
        }
    }
    Write-Host "-----------------------------" -ForegroundColor Green

    $vraVAVM = Import-VApp -Source $sourceOVA -VMHost $targetHost -OvfConfiguration $ovfProperties -Name $displayName -Datastore $datastore
    
    Write-Output "Changing VM Configuration"
    Set-VM -VM $vraVAVM -MemoryMB $memory -NumCpu $numCPU -Confirm:$false

    $adapter = Get-NetworkAdapter -VM $vraVAVM

    Write-Output "Connecting NIC Network"
    Set-NetworkAdapter -NetworkAdapter $adapter -PortGroup $network -Confirm:$false

    Write-Output "Starting VM"
    Start-VM -VM $vraVAVM
}

function Deploy-IaaSVM
{
    Write-Host "==========   Starting IaaS VM Deployment   ==========" -ForegroundColor Yellow

    $ip = $ScriptVariables.Get_Item("IaaSVMIPAddress")
    $subnetMask = $ScriptVariables.Get_Item("IaaSVMSubnetMask")
    $gateway = $ScriptVariables.Get_Item("IaaSVMGateway")
    $domain = $ScriptVariables.Get_Item("IaaSVMDomainName")
    $displayName = $ScriptVariables.Get_Item("IaaSVMDisplayName")
    $vmToCloneName = $ScriptVariables.Get_Item("IaaSVMToClone")
    $targetDatastore = $ScriptVariables.Get_Item("IaaSVMTargetDatastore")
    $targetHost = $ScriptVariables.Get_Item("IaaSVMTargetHost")
    $targetFolder = Get-Folder $ScriptVariables.Get_Item("IaaSVMTargetFolder")
    $domainUsername = $ScriptVariables.Get_Item("IaaSDomainUsername")
    $domainPassword = $ScriptVariables.Get_Item("IaaSDomainPassword")
    $workgroupName = $ScriptVariables.Get_Item("IaaSVMWorkgroupName")
    $dnsServer = $ScriptVariables.Get_Item("IaaSVMDNSServer")
    $dnsSuffix = $ScriptVariables.Get_Item("IaaSVMDNSSuffix")
    $hostname = $ScriptVariables.Get_Item("IaaSVMHostname")
    $adminPassword = $ScriptVariables.Get_Item("IaaSVMAdministratorPassword")
    $adminName = $ScriptVariables.Get_Item("IaaSAdministratorName")
    $orgName = $ScriptVariables.Get_Item("IaaSOrgName")
    $timezone = $ScriptVariables.Get_Item("IaaSTimezone")

    $memory = $ScriptVariables.Get_Item("IaaSVMMemoryMB")
    $numCPU = $ScriptVariables.Get_Item("IaaSVMNumCPUs")
    $network = $ScriptVariables.Get_Item("IaaSVMNetwork")
    $snapshotName = $ScriptVariables.Get_Item("IaasVMSnapshotToClone")

    try 
    {
        $existingSpec = Get-OSCustomizationSpec -Name IaaSSpec-unique-name

        if($existingSpec -eq $null)
        {
            Remove-OSCustomizationSpec -OSCustomizationSpec IaaSSpec-unique-name 
        }
    }
    catch { }

    $osSpecParameters = @{
        OSType = "Windows";
        Type = "Persistent";
        Name = "IaaSSpec-unique-name";
        FullName = $adminName
        AdminPassword = $adminPassword;
        ChangeSid = $true;
        DnsSuffix = $dnsSuffix;
        NamingScheme = "VM";
        OrgName = $orgName;
        TimeZone = $timezone;
    }

    
    if($domain -ne "" -and $domain -ne $null)
    {
        $osSpecParameters['Domain'] = $domain
        $osSpecParameters['DomainUsername'] = $domainUsername
        $osSpecParameters['DomainPassword'] = $domainPassword
    }
    else
    {
        $osSpecParameters['Workgroup'] = $workgroupName
    }

    if($productKey -ne "" -and $productKey -ne $null)
    {
        $osSpecParameters['ProductKey'] = $productKey
    }
        

    $spec = New-OSCustomizationSpec @osSpecParameters

    $spec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping –IpMode UseStaticIP –IpAddress $ip –SubnetMask $subnetMask –DefaultGateway $gateway –Dns $dnsServer

    $vmParameters = @{
        VMHost = $targetHost;
        Datastore = $targetDatastore;
        Location = $targetLocation;
        OSCustomizationSpec = $spec;
        VM = $vmToCloneName;
        Name = $displayName;
    }

    if($snapshotName -ne "")
    {
        $vmParameters['ReferenceSnapshot'] = $snapshotName
        $vmParameters['LinkedClone'] = $true
    }

    Write-Output "Cloning VM..."
    $iaasVM = New-VM @vmParameters

    while($iaasVM -eq $null)
    {
        $iaasVM = Get-VM $displayName
        
        Write-Host "Waiting for $displayName to be created"
        
        Start-Sleep -Seconds 30
        
    }

    Write-Output "Destroying temporary customization"
    Remove-OSCustomizationSpec -OSCustomizationSpec IaaSSpec-unique-name -Confirm:$false
    
    Write-Output "Changing VM Configuration"
    Set-VM -VM $iaasVM -MemoryMB $memory -NumCpu $numCPU -Confirm:$false

    $adapter = Get-NetworkAdapter -VM $iaasVM

    Write-Output "Connecting NIC Network"
    Set-NetworkAdapter -NetworkAdapter $adapter -PortGroup $network -Confirm:$false
    Set-NetworkAdapter -NetworkAdapter $adapter -StartConnected $true -Confirm:$false

    Write-Output "Starting VM"
    Start-VM -VM $iaasVM

}

function Run-IaaSPrereqs
{
    Write-Host "==========   Starting IaaS Pre-Req Routines   ==========" -ForegroundColor Yellow

    $iaasVM = Get-VM -Name $ScriptVariables.Get_Item("IaaSVMDisplayName")
    $domain = $ScriptVariables.Get_Item("IaaSVMDomainName")
    $username = ($domain + "\" + $ScriptVariables.Get_Item("IaaSDomainUsername"))
    $password = $ScriptVariables.Get_Item("IaaSDomainPassword")
    $serviceUser = $ScriptVariables.Get_Item("IaaSServiceAccountUsername")
    $servicePass = $ScriptVariables.Get_Item("IaaSServiceAccountPassword")
    $vraVARootPass = $ScriptVariables.Get_Item("vRAVARootPassword")
    $vraVAHostname = $ScriptVariables.Get_Item("vRAVAHostname")
    
    while($iaasVM.Guest.HostName -ne $ScriptVariables.Get_Item("IaaSVMHostName"))
    {
        $iaasVM = Get-VM -Name $ScriptVariables.Get_Item("IaaSVMDisplayName")
        Write-Output ("Waiting for IaaS HostName to update.  Current Value = " + $iaasVM.Guest.HostName + ".  Expected Value = " + $ScriptVariables.Get_Item('IaaSVMHostName') + ".")
        Start-Sleep -Seconds 30
    }

    while($vraVAVM.Guest.HostName -ne $ScriptVariables.Get_Item("vRAVAHostName"))
    {
        $vraVAVM = Get-VM -Name $ScriptVariables.Get_Item("vRAVADisplayName")
        Write-Output ("Waiting for vRA VA HostName to update.  Current Value = " + $vraVAVM.Guest.HostName + ".  Expected Value = " + $ScriptVariables.Get_Item('vRAVAHostName') + ".")
        Start-Sleep -Seconds 30
    }
    
    Write-Output "Copying Prereq files to guest"
    foreach($f in $iaasFiles)
    {
        Write-Output "     $f"
        Copy-VMGuestFile -Source $f -Destination "C:\temp\" -LocalToGuest -VM $iaasVM -GuestUser $username -GuestPassword $password -Force
        
    }
        
    Write-Output "Changing Execution Policy"
    #Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force
    Invoke-VMScript -VM $iaasVM -ScriptText "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force" -GuestUser $username -GuestPassword $password 

    Write-Output "Disabling Windows Firewall"
    Invoke-VMScript -VM $iaasVM -ScriptText "C:\Windows\System32\netsh.exe advfirewall set allprofiles state off" -GuestUser $username -GuestPassword $password 
    
    Write-Output "Disabling Authentication Loopback Check"
    Invoke-VMScript -VM $iaasVM -ScriptText "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe New-ItemProperty HKLM:\System\CurrentControlSet\Control\Lsa -Name 'DisableLoopbackCheck' -Value '1' -PropertyType dword" -GuestUser $username -GuestPassword $password 
    
    Write-Output "Installing vRA Management Agent"
    Invoke-VMScript -VM $iaasVM -ScriptText "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe C:\temp\InstallManagementAgent.ps1 https://${vraVAHostname}:5480 $serviceUser $servicePass $vraVARootPass" -GuestUser $username -GuestPassword $password 

    Write-Output "Restarting IaaS Server"
    Restart-VMGuest $iaasVM
    Start-Sleep -Seconds 10

    $iaasVM = Get-VM -Name $ScriptVariables.Get_Item("IaaSVMDisplayName")
    
    while($iaasVM.Guest.HostName -ne $ScriptVariables.Get_Item("IaaSVMHostName"))
    {
        $iaasVM = Get-VM -Name $ScriptVariables.Get_Item("IaaSVMDisplayName")
        Write-Output ("Waiting for IaaS HostName to update.  Current Value = " + $iaasVM.Guest.HostName + ".  Expected Value = " + $ScriptVariables.Get_Item('IaaSVMHostName') + ".")
        Start-Sleep -Seconds 30
    }
}

function Install-vRA
{
    Write-Host "==========   Starting vRA Install   ==========" -ForegroundColor Yellow

    $pass = $ScriptVariables.Get_Item("vRAVARootPassword")
    $displayName = $ScriptVariables.Get_Item("vRAVADisplayName")
    $vraVAVM = Get-VM $displayName

    Write-Host "Copying ha.properties to vRA VA"
    Copy-VMGuestFile -Source $vraInstallAnswerFile -Destination /usr/lib/vcac/tools/install/ha.properties -LocalToGuest -GuestUser root -GuestPassword $pass -VM $vraVAVM -Force

    Write-Host "Installing vRA & IaaS Components.  This process will take several minutes to complete."
    $scriptResult = Invoke-VMScript -VM $vraVAVM -ScriptText "/usr/lib/vcac/tools/install/vra-ha-config.sh" -GuestUser root -GuestPassword $pass 

    Write-Host $scriptResult.ScriptOutput

    if($scriptResult.ScriptOutput.Contains("[ERROR] Prerequisite check has failed!") -eq $true)
    {
        Write-Host "IaaS Pre-requisite check failed.  Restarting install..." -ForegroundColor Yellow
        Invoke-VMScript -VM $vraVAVM -ScriptText "/usr/lib/vcac/tools/install/vra-ha-config.sh" -GuestUser root -GuestPassword $pass 
    }

    Write-Host "Done."
}

Create-AnswerFile

Deploy-vRAAppliance

Deploy-IaaSVM

Run-IaaSPrereqs

Install-vRA

