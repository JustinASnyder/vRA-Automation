# vRA-Automation
Scripts and code relating to the automation of VMware vRealize Automation

# Automated Installation of vRA 7.2, 7.3, and 7.4
The vRA-Automation/Automated Install directory contains all the artifacts necessary to perform an automated install of a minimal configuration of any of the above stated versions of vRA.

To perform the install, copy all files locally to the same directory.  For vRA 7.2 and 7.3, remove the InstallManagementAgent.ps1 script and replace it by renaming the InstallManagementAgent-72-73.ps1 to InstallManagementAgent.ps1.  

Edit the deploymentVariables-Template.ps1 file and enter all desired parameters for the installation.  Optionally, save the config under a separate file name and update the file include in the vRA-Automated-Install.ps1 file to point to the new deploymentVariables file.

Edit the vRA-Automated-Install file with the appropriate prompt and include options at the top of the file.  It is possible to prompt for all entries without a value, prompt for passwords only, or prompt for nothing.  By default, anything that is necessary, but left empty, will be prompted for.

Connect-VIServer to the right vCenter Server, and execute the vRA-Automated-Install.ps1 script.
