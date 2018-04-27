Stop-VM vra-01 -Confirm:$false
Stop-VM vra-iaas-01 -Confirm:$false
Remove-VM vra-01 -DeletePermanently -Confirm:$false
Remove-VM vra-iaas-01 -DeletePermanently -Confirm:$false

Stop-VM hwlvra7201 -Confirm:$false
Stop-VM hwlvra72iaas01 -Confirm:$false
Remove-VM hwlvra7201 -DeletePermanently -Confirm:$false
Remove-VM hwlvra72iaas01 -DeletePermanently -Confirm:$false

