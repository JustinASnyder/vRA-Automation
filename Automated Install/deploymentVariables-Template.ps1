#========================================================================================
#  deploymentVariables-Template.ps1
#  Author:  Justin Snyder
#  Website: https://www.ltx.systems/
#  Date:    04/27/2018
#  Purpose: This script is included in the vRA-Automated-Install.ps1 script and
#           contains all the deployment variables for building the OVA, IaaS VM
#           and vRA silent install answer file values.  This script is a template that
#           can be copied and duplicated for multiple deployments, allowing the settings
#           to remain independent of the core deployment logic.
#========================================================================================

#Deployment variables that control VM configuration and OVF properties of the vRA VA deploymet
#enter default values here, set to "" if no default required
$ScriptVariables = @{
    #OVA deployment Settings
    "vRASourceOVA" = "c:\Path\To\vRA\VA\OVA\VMware-vR-Appliance-7.4.0.645-8229492_OVF10.ova";
    "vRAVADisplayName" = "vRA-01";
    "vRAVAHostname" = "";
    "vRAVATargetDatastore" = "";
    "vRAVATargetHost" = "";
    "vRAVATargetFolder" = "";

    #VM Hardware Config Settings
    #18GB RAM & 4CPUs are the OVA defaults, change these to resize the VM after deployment
    #Network name must match PortGroup name
    "vRAVAMemoryMB" = "18432";  
    "vRAVANumCPUs" = "4";
    "vRAVANetwork" = "";

    #OVA Security Settings
    "vRAVARootPassword" = "";  #Root password must have upper, lower, numeric, and special characters
    "vRAVASSHEnabled" = $true; #set to $false to disable SSH access to the virtual appliance
    
    #OVA IP Settings
    "vRAVAIPAddress" = "";
    "vRAVASubnetMask" = "";
    "vRAVAGateway" = "";
    
    #OVA DNS Settings
    "vRAVADomain" = "";
    "vRAVASearchPath" = "";
    "vRAVADNSServers" = "";
    
    #IaaS Clone Settings
    "IaaSVMToClone" = "";
    "IaasVMSnapshotToClone" = "";
    "IaaSVMDisplayName" = "vra-iaas-01";
    "IaaSVMTargetDatastore" = "";
    "IaaSVMTargetHost" = "";
    "IaaSVMTargetFolder" = "";
    
    #IaaS VM Hardware Config Settings
    "IaaSVMMemoryMB" = "4096";
    "IaaSVMNumCPUs" = "4";
    "IaaSVMNetwork" = "";

    #IaaS VM Customization Settings
    "IaaSVMHostname" = "";
    #---Domain Membership - leave domain blank to join workgroup instead
    "IaaSVMDomainName" = "";  #Windows NETBIOS Name only, not fully qualified
    "IaaSDomainUsername" = "Administrator";  #username only, domain not required
    "IaaSDomainPassword" = "";
    "IaaSVMWorkgroupName" = "WORKGROUP";
    #---IP Settings
    "IaaSVMIPAddress" = "";
    "IaaSVMSubnetMask" = "255.255.255.0";
    "IaaSVMGateway" = "";
    #---DNS Settings
    "IaaSVMDNSServer" = "";
    "IaaSVMDNSSuffix" = "";
    #---Admin Password
    "IaaSVMAdministratorPassword" = "P@ssword1";
    #---Windows User Registration Info
    "IaaSAdministratorName" = "Administrator";
    "IaaSOrgName" = "Org";
    #---Windows Licensing Info
    "IaaSLicensingMode" = "PerSeat";
    "IaaSMaxLicenseCount" = "5";
    #---Timezone Info - US East=035, Central=020, Mountain=010, Pacific=004, Alaska=003, Hawaii=002
    "IaaSTimezone" = "035";

    #IaaS Service Account Info - to be granted logon as a service right
    #Service account needs admin rights on the IaaS server to remediate pre-req check findings
    "IaaSServiceAccountUsername" = "";
    "IaaSServiceAccountPassword" = "";
}

#Answer file values for the vRA Silent Install
$answerFileValues = @{

    #---Self-Signed Cert info
    "acceptEULA" = "true";
    "certSign" = "sha256";
    "keyLength" = "4096";
    "keyType" = "RSA";
    "daysValid" = "1825";
    "orgName" = "Org";
    "ou" = "OU";
    "countryCode" = "US";
    
    #---vRA License Key
    "vraLicense" = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX";  #eval license; replace with real license
    
    "sleepMax" = "1200";
    
    "ntpServer" = "";  #NTP Server to use for time
    
    #---IaaS Settings
    "installIaas" = "True";
    "useSingleIaasCredentials" = "False";
    "singleIaasUser" = "";
    "singleIaasPassword" = "";
    
    #---Horizon IdM Settings - default tenant vsphere.local
    "horizonUser" = "administrator";
    "horizonPassword" = "P@ssword1"; #administrator@vsphere.local password; change from default
    "ssoTenant" = "vsphere.local";
    
    #---HA Virtual Appliance Config
    "secondaryVAHostnames" = "";
    "secondaryVAUsers" = "";
    "secondaryVAPasswords" = "";
    
    #---IaaS Web Server Config
    "iaasWebHostnames" = "";    #for basic install, IaaS Server FQDN
    "iaasWebUsernames" = "";    #Service Account to use
    "iaasWebPasswords" = "";    #Password for Service Account

    #---IaaS Model Manager Config
    "iaasMSHostnames" = "";    #for basic install, IaaS Server FQDN
    "iaasMSUsernames" = "";    #Service Account to use
    "iaasMSPasswords" = "";    #Password for Service Account
    
    #---IaaS DEM Config
    "iaasDEMHostnames" = "";    #for basic install, IaaS Server FQDN
    "iaasDEMUsernames" = "";    #Service Account to use
    "iaasDEMPasswords" = "";    #Password for Service Account
    
    #---Load balanced naming config
    "vraLBFQDN" = "";    #vRA VA FQDN
    "vraWebFQDN" = "";    #for basic install, IaaS Server FQDN
    "vraMSFQDN" = "";    #for basic install, IaaS Server FQDN
    
    #---IaaS MS SQL Database Config
    "MSSQLServer" = "";   #SQL Server to use for IaaS SQL DB
    "MSSQLInstance" = "";   #Instance name, leave blank for default instance
    "iaasDBName" = "vra-74";  #Ensure this database does not already exist on the server
    "iaasDBDataPath" = "";
    "iaasDBLogPath" = "";
    "dbUseEncryption" = "False";
    "iaasDBWindowsAuth" = "True";
    "MSSQLUser" = "";
    "MSSQLPass" = "";
    "useExistingDatabase" = "False";
    "iaasPassphrase" = "P@ssword1";       #DB Encryption Passphrase; change from default
    
    #---IaaS Web Server Settings
    "webSiteName" = "Default Web Site";
    "httpsPort" = "443";
    
    #---vSphere Agent Settings
    "vraAgentHostnames" = "";    #for basic install, IaaS Server FQDN
    "vraAgentUsernames" = "";    #Service Account to use
    "vraAgentPasswords" = "";    #Password for Service Account
    "vSphereAgentNames" = "vCenter";
    "vSphereAgentEndpoints" = "vCenter";
    
    #---EPI Agent Settings
    "epiAgentHostnames" = "";
    "epiAgentUsernames" = "";
    "epiAgentPasswords" = "";
    "epiAgentNames" = "";
    "epiServerTypes" = "";
    "epiServerNames" = "";
    
    #---Hyper-V Agent Settings
    "hyperVAgentHostnames" = "";
    "hyperVAgentUsernames" = "";
    "hyperVAgentPasswords" = "";
    "hyperVAgentNames" = "";
    "hyperVUsernames" = "";
    "hyperVPasswords" = "";
    
    #---VDI Agent Settings
    "vdiAgentHostnames" = "";
    "vdiAgentUsernames" = "";
    "vdiAgentPasswords" = "";
    "vdiAgentNames" = "";
    "vdiTypes" = "";
    "vdiServerNames" = "";
    "vdiXenDesktopVersions" = "";
    
    #---Xen Agent Settings
    "xenAgentHostnames" = "";
    "xenAgentUsernames" = "";
    "xenAgentPasswords" = "";
    "xenAgentNames" = "";
    "xenUsernames" = "";
    "xenPasswords" = "";
    
    #---WMI Agent Settings
    "wmiAgentHostnames" = "";
    "wmiAgentUsernames" = "";
    "wmiAgentPasswords" = "";
    "wmiAgentNames" = "";
    
    #---Apply fixes after pre-req check
    "applyFixes" = "True";
    
    #---Initial Content Settings
    "createInitialContent" = "False";
    "configurationAdministratorPassword" = "";
    
    #---IaaS Model Manager Certificate Info
    "iaasMSCertificate" = "";
    "iaasMSCertificatePK" = "";
    "iaasMSPKPassword" = "";
    
    #---IaaS Web Certificate Info
    "iaasWebCertificate" = "";
    "iaasWebCertificatePK" = "";
    "iaasWebPKPassword" = "";
    
    #---vRA Virtual Appliance Web Certificate Info
    "vraWebCertificate" = "";
    "vraWebCertificatePK" = "";
    "vraWebPKPassword" = "";
}