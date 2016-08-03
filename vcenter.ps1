############################# INFORMATION #######################################
# VMWare Capacity & Performance Report
# Marc Vincent Davoli (Find me on LinkedIn! http://ca.linkedin.com/in/marcvincentdavoli/)
# PREREQUISITES for this script: Powershell V2, PowerCLI 5.0, Microsoft Chart Controls for .NET Framework (download from this link:
# http://www.microsoft.com/en-us/download/details.aspx?id=14422)
# INPUT for this script: vCenter server IP/hostname, vCenter server credentials, SMTP server IP/hostname
# OUTPUT for this script: E-mailed Report, Report.HTML and Attachments, 1 for each chart (in the working directory)
# Notice 1 : CPU and Memory provisioning potential is calculated by removing 1 host
# Notice 2 : Datastore space provisioning potential is calculated by removing removing 5%


############################# CHANGELOG #######################################
# February 2013		First version
# April 2013		Bugfixes, Added Per Cluster report
# July 2013			Bugfixes, Added Cluster Resilience & Provisionning Potential reports, other minor code adjustements
# January 2014		Added Consolidation ratio, ESXi Hardware & Software Information table, vCenter version, Print Computer name and script version
# May 2015			Fixed issue with Cluster charts not appearing in e-mail report, cause by a space in the cluster name

################################ CONSTANTS ######################################

Write-Host Loading...

#-------------------------CHANGE THESE VALUES--------------------------------
$SMTPServer = ""
$vCenterServerName = ""
#-----------------------------------------------------------------------------

$ScriptVersion = "v2.1 - Community Edition" # Included in the Runtime info in $HTMLFooter


############################# GLOBAL VARIABLES ####################################

$global:ArrayOfNames = @()
$global:ArrayOfValues = @()
$Attachments = @()
$json = @{}

############################## PREPROCESSING ####################################

Write-Host Preprocessing...

# Create a folder for temporary image files
#IF ((Test-Path -path .\Temp) -ne $True) {$TempFolder = New-Item .\Temp -type directory} else {$TempFolder = ".\Temp"}


Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
Connect-VIServer $vCenterServerName

$DC = Get-Datacenter | Sort-Object -Property Name #| Select-Object -First 2
$Clusters = Get-Cluster | Sort-Object -Property Name #| Select-Object -First 1
$VMHosts = Get-VMHost | Sort-Object -Property Name #| Select-Object -First 1
$VM = Get-VM | Sort-Object -Property Name #| Select-Object -First 2
$Datastores = Get-Datastore | Sort-Object -Property Name #| Select-Object -First 1
$Templates = Get-Template | Sort-Object -Property Name #| Select-Object -First 2
$ResourcePools = Get-ResourcePool | Sort-Object -Property Name #| Select-Object -First 2
$Snapshots = $VM | Get-Snapshot #| Select-Object -First 2
$Date = Get-Date | Sort-Object -Property Name #| Select-Object -First 2



################################ FUNCTIONS ######################################

Function GetTotalCPUCyclesInGhz ($VMHostsTemp) {

	$TotalCPUCyclesInGHz = $VMHostsTemp | Measure-Object -Property CpuTotalMhz -Sum # Count total CPU in Mhz
	$TotalCPUCyclesInGHz = $TotalCPUCyclesInGHz.Sum -as [int] # Convert from String to Int
	$TotalCPUCyclesInGHz = $TotalCPUCyclesInGHz / 1000 # Divide by 1000 to convert from MHz to GHz
	$TotalCPUCyclesInGHz = [system.math]::ceiling($TotalCPUCyclesInGHz) # Round down
	return $TotalCPUCyclesInGHz
}

Function GetTotalNumberofCPUs ($VMHostsTemp){

	$TotalCPU = $VMHostsTemp | Measure-Object -Property NumCpu -Sum # Count total RAM in MB
	$TotalCPU = $TotalCPU.Sum
	return $TotalCPU
}

Function GetTotalMemoryInGB ($VMHostsTemp){

	$TotalRAMinGB = $VMHostsTemp | Measure-Object -Property MemoryTotalMB -Sum # Count total RAM in MB
	$TotalRAMinGB = $TotalRAMinGB.Sum -as [int] # Convert from String to Int
	$TotalRAMinGB = $TotalRAMinGB / 1024 # Divide by 1024 to convert from MB to GB
	$TotalRAMinGB = [system.math]::ceiling($TotalRAMinGB) # Round down
	return $TotalRAMinGB
}

Function GetTotalDatastoreDiskSpaceinGB ($DatastoresTemp) {

	$TotalDatastoreDiskSpaceinGB = $DatastoresTemp | Measure-Object -Property FreeSpaceMB -Sum # Count total  MB
	$TotalDatastoreDiskSpaceinGB = $TotalDatastoreDiskSpaceinGB.Sum -as [int] # Convert from String to Int
	$TotalDatastoreDiskSpaceinGB = $TotalDatastoreDiskSpaceinGB / 1024 # Divide by 1024 to convert from MB to GB
	$TotalDatastoreDiskSpaceinGB = [system.math]::ceiling($TotalDatastoreDiskSpaceinGB) # Round down
	return $TotalDatastoreDiskSpaceinGB
}


Function GetVMHostMemoryinGB ($vmhosttemp){

	$TempVMHostRAMinGB = $vmhosttemp.MemoryTotalMB -as [int] # Convert from String to Int
	$TempVMHostRAMinGB = $TempVMHostRAMinGB / 1024 # Divide by 1024 to convert from MB to GB
	$TempVMHostRAMinGB = [system.math]::ceiling($TempVMHostRAMinGB) # Round down
	return $TempVMHostRAMinGB
}

Function GetVMHostAverageCPUUsagePercentage ($vmhosttemp) { #For the last 30 days

	$AverageCPUUsagePercentage = Get-Stat -Entity ($vmhosttemp)-start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 31 -stat cpu.usage.average
	$AverageCPUUsagePercentage = $AverageCPUUsagePercentage | Measure-Object -Property value -Average
	$AverageCPUUsagePercentage = $AverageCPUUsagePercentage.Average
	$AverageCPUUsagePercentage = [system.math]::ceiling($AverageCPUUsagePercentage) # Round up
	return $AverageCPUUsagePercentage
}

Function GetVMHostAverageMemoryUsagePercentage ($vmhosttemp) { #For the last 30 days

	$AverageMemoryUsagePercentage = Get-Stat -Entity ($vmhosttemp)-start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 31 -stat mem.usage.average
	$AverageMemoryUsagePercentage = $AverageMemoryUsagePercentage | Measure-Object -Property value -Average
	$AverageMemoryUsagePercentage = $AverageMemoryUsagePercentage.Average
	$AverageMemoryUsagePercentage = [system.math]::ceiling($AverageMemoryUsagePercentage) # Round up
	return $AverageMemoryUsagePercentage
}

Function GetDatastoreCurrentDiskSpaceUsagePercentage ($DatastoreTemp) {

	$DatastoreFreeSpaceinMB = $DatastoreTemp.FreeSpaceMB -as [int]
	$DatastoreCapacityinMB= $DatastoreTemp.CapacityMB -as [int]
	$DatastoreCurrentDiskSpaceUsagePercentage = 100 - ($DatastoreFreeSpaceinMB / $DatastoreCapacityinMB *100)
	$DatastoreCurrentDiskSpaceUsagePercentage = [system.math]::ceiling($DatastoreCurrentDiskSpaceUsagePercentage) # Round up
	return $DatastoreCurrentDiskSpaceUsagePercentage
}


Function GetDatastoreCapacityinGB ($DatastoreTemp) {

	$DatastoreCapacityinGB = $DatastoreTemp.CapacityMB -as [int]
	$DatastoreCapacityinGB = $DatastoreCapacityinGB / 1024 # Divide by 1024 to convert from MB to GB
	$DatastoreCapacityinGB = [system.math]::ceiling($DatastoreCapacityinGB) # Round up
	return $DatastoreCapacityinGB
}

Function GetNumberofVMsInDatastore ($DatastoreTemp) {
	$DatastoreTemp = $DatastoreTemp | Get-VM | Measure-Object | Select-Object Count
	return $DatastoreTemp.Count
}

Function GetDatastoreAllocationPercentage ($DatastoreTemp) {
	$DatastoreTemp = $DatastoreTemp | Get-View
	$DSAllocationTemp = [math]::round(((($DatastoreTemp.Summary.Capacity - $DatastoreTemp.Summary.FreeSpace)`
						+ $DatastoreTemp.Summary.Uncommitted)*100)/$DatastoreTemp.Summary.Capacity,0)
	return $DSAllocationTemp
}

Function GetVMHostCurrentMemoryUsagePercentage ($vmhosttemp) {

	$MemoryUsageinMhz = $vmhosttemp.MemoryUsageMB -as [int]
	$MemoryTotalinMhz = $vmhosttemp.MemoryTotalMB -as [int]
	$MemoryUsagePercentage = $MemoryUsageinMhz / $MemoryTotalinMhz *100
	$MemoryUsagePercentage = [system.math]::ceiling($MemoryUsagePercentage) # Round up
	return $MemoryUsagePercentage
}


Function GetVMHostCurrentCPUUsagePercentage ($vmhosttemp) {

	$CPUUsageinMhz = $vmhosttemp.CpuUsageMhz -as [int]
	$CPUTotalinMhz = $vmhosttemp.CpuTotalMhz -as [int]
	$CPUUsagePercentage = $CPUUsageinMhz / $CPUTotalinMhz *100
	$CPUUsagePercentage = [system.math]::ceiling($CPUUsagePercentage) # Round up
	return $CPUUsagePercentage
}

Function GetVMAverageCPUUsage ($VMsTemp) {

	$AverageVMCPUUsage = Get-Stat -Entity ($VMsTemp) -MaxSamples 1 -stat cpu.usagemhz.average
	$AverageVMCPUUsage = $AverageVMCPUUsage | Measure-Object -Property value -Average
	$AverageVMCPUUsage = $AverageVMCPUUsage.Average
	#$AverageVMCPUUsage = $AverageVMCPUUsage / 1000 # Divide by 1000 to convert from MHz to GHz # VALUE NOT HIGH ENOUGH
	$AverageVMCPUUsage = [system.math]::ceiling($AverageVMCPUUsage) # Round up
	return $AverageVMCPUUsage
}

Function GetVMAverageMemoryUsage ($VMsTemp) {

	$TotalVMMemoryinMB = $VMsTemp | Measure-Object -Property MemoryMB -Sum # Count total RAM in MB
	$TotalVMMemoryinMB = $TotalVMMemoryinMB.Sum -as [int] # Convert from String to Int
	#$TotalVMMemoryinGB = $TotalVMMemoryinMB / 1024 # Divide by 1024 to convert from MB to GB # VALUE NOT HIGH ENOUGH
	$AverageVMMemoryInGB = $TotalVMMemoryinMB / $VMsTemp.Length # Divide by number of VMs
	$AverageVMMemoryInGB = [system.math]::ceiling($AverageVMMemoryInGB) # Round down
	return $AverageVMMemoryInGB
}

Function GetVMAverageDatastoreUsage ($VMsTemp) {

	$TotalVMProvisionedSpaceinGB = $VMsTemp | Measure-Object -Property ProvisionedSpaceGB -Sum # Count total RAM in MB
	$TotalVMProvisionedSpaceinGB = $TotalVMProvisionedSpaceinGB.Sum -as [int] # Convert from String to Int
	$VMAverageDatastoreUsage = $TotalVMProvisionedSpaceinGB / $VMsTemp.Length # Divide by number of VMs
	$VMAverageDatastoreUsage = [system.math]::ceiling($VMAverageDatastoreUsage) # Round up
	return $VMAverageDatastoreUsage
}

Function GetVMTotalMemory ($VMsTemp) {

	$VMTotalMemory = $VMsTemp | Measure-Object -Property MemoryMB -Sum
	$VMTotalMemory = $VMTotalMemory.Sum / 1024 # Divide by 1024 to convert from MB to GB
	$VMTotalMemory = [system.math]::ceiling($VMTotalMemory)
	return $VMTotalMemory
}

Function GetVMTotalCPUs ($VMsTemp) {

	$VMTotalCPUs = $VMsTemp  | Measure-Object -Property NumCpu -Sum
	return $VMTotalCPUs.Sum
}


Function GetCPUSlotsAvailable ($VMHostsInClusterTemp, $ClusterVMAverageCPUUsageTemp) {

	$VMHostsTotalCPUMhz = $VMHostsInClusterTemp | Measure-Object -Property CpuTotalMhz -Sum
	$VMHostsUsedCPUMhz = $VMHostsInClusterTemp | Measure-Object -Property CpuUsageMhz -Sum
	$VMHostsTotalCPUMhz = $VMHostsTotalCPUMhz.Sum * 0.90 # Keep 10% available for best practice
	$VMHostsUsedCPUMhz = $VMHostsUsedCPUMhz.Sum
	$VMHostsAvailableCPUMhz = $VMHostsTotalCPUMhz - $VMHostsUsedCPUMhz
	$ClusterCPUSlots = $VMHostsAvailableCPUMhz / $ClusterVMAverageCPUUsageTemp # The rest divided by 1 CPU Slot
	$ClusterCPUSlots = [system.math]::floor($ClusterCPUSlots) # Round down
	return $ClusterCPUSlots
}



Function GetMemorySlotsAvailable ($VMHostsInClusterTemp, $ClusterVMAverageMemoryUsageTemp) {

	$VMHostsTotalMemoryMB = $VMHostsInClusterTemp | Measure-Object -Property MemoryTotalMB -Sum
	$VMHostsUsedMemoryMB = $VMHostsInClusterTemp | Measure-Object -Property MemoryUsageMB -Sum
	$VMHostsTotalMemoryMB = $VMHostsTotalMemoryMB.Sum * 0.90 # Keep 10% available for best practice
	$VMHostsUsedMemoryMB = $VMHostsUsedMemoryMB.Sum
	$VMHostsAvailableMemoryMB = $VMHostsTotalMemoryMB - $VMHostsUsedMemoryMB
	$ClusterMemorySlots = $VMHostsAvailableMemoryMB / $ClusterVMAverageMemoryUsageTemp # The rest divided by 1 Memory Slot
	$ClusterMemorySlots = [system.math]::floor($ClusterMemorySlots) # Round down
	return $ClusterMemorySlots
}


Function GetDatastoreSlotsAvailable ($DatastoresInClusterTemp, $ClusterVMAverageMemoryUsageTemp) {

	# Remove 5% of Datastore capacity for Best Practices
	$DatastoreCapacityTemp = $DatastoresInClusterTemp | Measure-Object -Property CapacityMB -Sum
	$DatastoreCapacityMinus5Percent = $DatastoreCapacity.Sum * 0.95
	$5PercentOfDatastoreCapacity = $DatastoreCapacity.Sum - $DatastoreCapacityMinus5Percent
	$DatastoreFreeSpaceMB = $DatastoreFreeSpaceMB - $5PercentOfDatastoreCapacity

	$DatastoreFreeSpaceMB = $DatastoresInClusterTemp | Measure-Object -Property FreeSpaceMB -Sum
	$DatastoreFreeSpaceMB = $DatastoreFreeSpaceMB.Sum / 1024 # Divide by 1024 to convert from MB to GB
	$DatastoreFreeSpaceMB = $DatastoreFreeSpaceMB - $5PercentOfDatastoreCapacity # Keep 5% available for best practice
	$ClusterDatastoreSlots = $DatastoreFreeSpaceMB / $ClusterVMAverageMemoryUsageTemp # Divided by 1 Memory Slot
	$ClusterDatastoreSlots = [system.math]::floor($ClusterDatastoreSlots) # Round down
	return $ClusterDatastoreSlots
}

Function GetVMProvisioningPotential ($CPUSLOTS, $MEMORYSLOTS, $DATASTORESLOTS) {

	if ($CPUSLOTS -le $MEMORYSLOTS -and  $CPUSLOTS -le $DATASTORESLOTS){ return ([String]$CPUSLOTS + ". CPU is your limiting factor.")}
	if ($MEMORYSLOTS -le $CPUSLOTS -and  $MEMORYSLOTS -le $DATASTORESLOTS){ return ([String]$MEMORYSLOTS + ". Memory is your limiting factor.")}
	if ($DATASTORESLOTS -le $CPUSLOTS -and  $DATASTORESLOTS -le $MEMORYSLOTS){ return ([String]$DATASTORESLOTS + ". Datastore Disk Space is your limiting factor.")}

}


Function ListVCenterInventory () {

	$HostTemp = Get-VMHost | Select-Object -First 1

	$metadata = @{}
	$version = (($HostTemp | Select-Object @{N="vCenterVersion";E={$global:DefaultVIServers | where {$_.Name.ToLower() -eq ($HostTemp.ExtensionData.Client.ServiceUrl.Split('/')[2]).ToLower()} | %{"$($_.Version) Build $($_.Build)"}   }}).vCenterVersion)

	$metadata.version = [String]$version
    $metadata.dc_count =  $DC.Count
    $metadata.cluster_count = $Clusters.Count
    $metadata.host_count = $VMHosts.Count
    $metadata.total_cpu = [String](GetTotalCPUCyclesInGhz ($VMHosts)) + " GHz"
    $metadata.cpu_count = (GetTotalNumberofCPUs ($VMHosts))
    $metadata.total_ram = [String](GetTotalMemoryInGB ($VMHosts)) + " GB"
    $metadata.vms_count = $VM.Count
    $metadata.template_count = $Templates.Count
    $metadata.recource_pool_count = $ResourcePools.Count
    $metadata.consolidation_ratio = [String][system.math]::floor($VM.Count / $VMHosts.Count) + ":1"

	return $metadata
}

Function BuildESXiSoftwareAndHardwareInfoObj ($VMHostsTemp) {
	$hardware = @()

	Write-Host "          " Gathering ESXi Hardware and Software Information...

	$VMHostsTemp | Sort-Object name | ForEach-Object {
		Write-Host "          " Gathering $_.Name "Hardware statistics..."
		$tmp = @{}
		$tmp.host = $_.Name
		$tmp.model = $_.Manufacturer + " " + $_.Model
		$tmp.cpu_count = $_.NumCpu
		$tmp.total_ram = [String](GetTotalMemoryInGB ($_)) + "GB"
		$tmp.version = [String]$_.Version + " Build " + $_.Build
		$tmp.uptime = [String]($_ | Get-View | select @{N="Uptime"; E={(Get-Date) - $_.Summary.Runtime.BootTime}}).Uptime.Days + " Days"
		$hardware += $tmp
	}

	return $hardware
}




Function ListClusterInventory ($ClusterTemp) {

	Write-Host "          " Gathering $ClusterTemp.Name "inventory..."

	# Get inventory objects for this cluster only
	$VMHostsTemp = Get-Cluster $ClusterTemp.Name | Get-VMHost | Sort-Object -Property Name #| Select-Object -First 1
	$DatastoresTemp = Get-Cluster $ClusterTemp.Name | Get-VMHost | Get-Datastore | Sort-Object -Property Name #| Select-Object -First 1
	$VMTemp = Get-Cluster $ClusterTemp.Name | Get-VM | Sort-Object -Property Name #| Select-Object -First 1
	$ResourcePoolsTemp = Get-Cluster $ClusterTemp.Name | Get-ResourcePool | Sort-Object -Property Name #| Select-Object -First 1
	$NbOfResourcePoolsTemp = $ResourcePoolsTemp | Measure-Object;

	$metadata = @{}

	$metadata.host_count = $VMHostsTemp.Count
    $metadata.total_cpu = [String](GetTotalCPUCyclesInGhz ($VMHostsTemp)) + " GHz"
    $metadata.cpu_count = (GetTotalNumberofCPUs ($VMHostsTemp))
    $metadata.total_ram = [String](GetTotalMemoryInGB ($VMHostsTemp)) + " GB"
    $metadata.datastore_count = $DatastoresTemp.Count
    $metadata.total_space =  [String](GetTotalDatastoreDiskSpaceinGB ($DatastoresTemp)) + "GB"
    $metadata.vms_count = $VMTemp.Count
    $metadata.recource_pool_count = $NbOfResourcePoolsTemp.Count
    $metadata.consolidation_ratio = [String][system.math]::floor($VMTemp.Count / $VMHostsTemp.Count) + ":1"


	return $metadata

}

Function ReinitializeArrays (){ #Reinitialize variables for reuse
	Clear-Variable -Name ArrayOfNames
	Clear-Variable -Name ArrayOfValues
	$global:ArrayOfNames = @()
	$global:ArrayOfValues = @()
}

Function CreateVMHostCPUUsageObj ($VMHostsTemp){ # Builds CPU Obj and populates Arrays used to create chart

	$cpu = @()

	$VMHostsTemp | Sort-Object name | ForEach-Object {
		Write-Host "          " Gathering $_.Name "CPU usage statistics..."
		$tmp = @{}
		$tempVMHostAverageCPUUsagePercentage = (GetVMHostAverageCPUUsagePercentage $_)

		$tmp.host = $_.name
		$tmp.cpu_count = $_.NumCpu
		$tmp.cur_cpu_usage =  [String](GetVMHostCurrentCPUUsagePercentage $_) + "%"
		$tmp.avg_cpu_usage = [String]($tempVMHostAverageCPUUSagePercentage) + "%"
		$global:ArrayOfNames += $_.Name
		$global:ArrayOfValues += ($tempVMHostAverageCPUUSagePercentage)
		$cpu += $tmp
	}

	return $cpu
}

Function CreateVMHostMemoryUsageObj ($VMHostsTemp){ # Builds Memory Obj and populates Arrays used to create chart

	$memory = @()

	$VMHostsTemp | Sort-Object name | ForEach-Object {
		Write-Host "          " Gathering $_.Name "Memory usage statistics..."
		$tmp = @{}
		$tempVMHostAverageMemoryUsagePercentage = (GetVMHostAverageMemoryUsagePercentage $_)

		$tmp.host = $_.name
		$tmp.total_ram = [String](GetVMHostMemoryinGB $_) + "GB"
		$tmp.cur_mem_usage =  [String](GetVMHostCurrentMemoryUsagePercentage $_) + "%"
		$tmp.avg_mem_usage = [String]($tempVMHostAverageMemoryUsagePercentage) + "%"
		$global:ArrayOfNames += $_.Name
		$global:ArrayOfValues += ($tempVMHostAverageMemoryUsagePercentage)
		$memory += $tmp
	}

	return $memory
}

Function CreateDatastoreUsageObj ($DatastoresTemp){ # Builds Datastore HTML Obj and populates Arrays used to create chart

	$datastore = @()

	$DatastoresTemp | Sort-Object name | ForEach-Object {
		Write-Host "          " Gathering $_.Name "Datastore usage statistics..."
		$tmp = @{}

		$tmp.name = $_.name
		$tmp.total_space = [String](GetDatastoreCapacityinGB $_) + "GB"
		$tmp.cur_disk_usage =  [String](GetDatastoreCurrentDiskSpaceUsagePercentage $_) + "%"
		$tmp.total_vms = (GetNumberofVMsInDatastore $_)
		$tmp.commitment = [String](GetDatastoreAllocationPercentage $_) + "%"
		$global:ArrayOfNames += $_.Name
		$global:ArrayOfValues += (GetDatastoreCurrentDiskSpaceUsagePercentage $_)
		$datastore += $tmp
	}

	return $datastore
}

Function CreateClusterProvisioningPotentialObjs ($ClusterTemp) {

	Write-Host "          " Gathering Cluster Provisioning Information for Cluster $ClusterTemp.Name

	$prov = @{}
	$prov.vm_stats = @{}
	$prov.vm_ra = @{}

	$VMsInClusterTemp = $ClusterTemp | Get-VM

	# Remove biggest host from collection
	$BiggestHostInCluster = $ClusterTemp | Get-VMHost | Sort-Object MemoryTotalMB -Descending | Select-Object -First 1
	$VMHostsInClusterMinusBiggest = $ClusterTemp | Get-VMHost | Where-Object {$_.Name -ne $BiggestHostInCluster.Name}
	$DatastoresInClusterMinusBiggestHosts = $VMHostsInClusterMinusBiggest | Get-Datastore

	$ClusterVMAverageCPUUsage = (GetVMAverageCPUUsage ($VMsInClusterTemp))
	$ClusterVMAverageMemoryUsage = (GetVMAverageMemoryUsage ($VMsInClusterTemp))
	$ClusterVMAverageDatastoreUsage = (GetVMAverageDatastoreUsage ($VMsInClusterTemp))

	$AvailableCPUSlotsInCluster = (GetCPUSlotsAvailable $VMHostsInClusterMinusBiggest $ClusterVMAverageCPUUsage)
	$AvailableMemorySlotsInCluster = (GetMemorySlotsAvailable $VMHostsInClusterMinusBiggest $ClusterVMAverageMemoryUsage)
	$AvailableDatastoreSlotsInCluster  = (GetDatastoreSlotsAvailable $DatastoresInClusterMinusBiggestHosts $ClusterVMAverageDatastoreUsage)

	$prov.message = "The approximate number of Virtual Machines you can provision safely in this cluster is " + [String](GetVMProvisioningPotential $AvailableCPUSlotsInCluster $AvailableMemorySlotsInCluster $AvailableDatastoreSlotsInCluster)

    $prov.vm_stats.total_vms = $VMsInCluster.Length
    $prov.vm_stats.avg_cpu_usage = [String]$ClusterVMAverageCPUUsage + "MHz"
    $prov.vm_stats.avg_mem_usage = [String]$ClusterVMAverageMemoryUsage + "MB"
    $prov.vm_stats.avg_disk_usage = [String]$ClusterVMAverageDatastoreUsage + "GB"

    $prov.vm_ra.total_cpu_slots = $AvailableCPUSlotsInCluster
    $prov.vm_ra.total_memory_slots = $AvailableMemorySlotsInCluster
    $prov.vm_ra.total_disk_slots = $AvailableDatastoreSlotsInCluster

	return $prov
 }

Function CreateClusterResilienceObj ($ClusterTemp) {

	Write-Host "          " Gathering Cluster Resilience Information for Cluster $ClusterTemp.Name

	# Get HA info
	$HAEnabled = $ClusterTemp | Select-Object HAEnabled; $HAEnabled = $HAEnabled.HAEnabled
	$ACEnabled = $ClusterTemp | Select-Object HAAdmissionControlEnabled; $ACEnabled = $ACEnabled.HAAdmissionControlEnabled
	$ACPolicy = "N/A"
	$HostLossTolerance = 0

	# GET HA Admission Control Policy
	if ($HAEnabled -and $ACEnabled){

		if ((($ClusterTemp | Select-Object HAFailoverlevel).HAFailoverLevel) -eq 0){ # If protection setting is NOT a # of hosts

			$ClusterView = Get-View -ViewType "ClusterComputeResource" -Filter @{"Name" = $ClusterTemp.Name}
			$ACPolicyInteger = $ClusterView.configuration.dasConfig.admissionControlpolicy.cpuFailoverResourcesPercent
			$ACPolicy = [String]$ACPolicyInteger  + " % of resources reserved"


			# CHART VALUE PREPARATIONS
			$ClusterUsedMemory = ($ClusterTemp | Get-VMHost | Measure-Object MemoryUsageMB -Sum).sum
			$ClusterTotalMemory = ($ClusterTemp | Get-VMHost | Measure-Object MemoryTotalMB -Sum).sum
			$ClusterFreeMemory = $ClusterTotalMemory - $ClusterUsedMemory - $ACPolicyInteger
			$ClusterUsedMemoryPercentage = [system.math]::floor($ClusterUsedMemory * 100 / $ClusterTotalMemory)
			$ClusterFreeMemoryPercentage = [system.math]::floor($ClusterFreeMemory * 100 / $ClusterTotalMemory)
			$ClusterFreeMemoryPercentage = $ClusterFreeMemoryPercentage - $ACPolicyInteger

			$global:ArrayOfNames += "Used"
			$global:ArrayOfValues += $ClusterUsedMemoryPercentage

			$global:ArrayOfNames += "Free"
			$global:ArrayOfValues += $ClusterFreeMemoryPercentage

			$global:ArrayOfNames += "HA Admission Control Reservation"
			$global:ArrayOfValues += $ACPolicyInteger

			# Host Loss Tolerance Calculation
			$BiggestHostInCluster = $ClusterTemp | Get-VMHost | Sort-Object MemoryTotalMB -Descending | Select-Object -First 1
			$HAReservedMemory = ($ACPolicyInteger/100) * ($ClusterTemp | Get-VMHost | Measure-Object MemoryTotalMB -Sum).sum
			$HostLossTolerance = $HAReservedMemory / $BiggestHostInCluster.MemoryTotalMB
			$HostLossTolerance = [System.Math]::Round($HostLossTolerance,2)


		}else{ # If protection setting is a # of hosts

			$ACPolicy =  ($ClusterTemp | Select-Object HAFailoverlevel).HAFailoverLevel
			$ACPolicy = [String]$ACPolicy  + " host(s) reserved"
			$HostLossTolerance = ($ClusterTemp | Select-Object HAFailoverlevel).HAFailoverLevel
		}
	}


	$rels = @{}
	$rels.message = "This cluster can survive the loss of approximately " + $HostLossTolerance + " host(s)"
	$rels.ha_enabled = [system.convert]::ToString($HAEnabled).ToLower()
	$rels.ace_enabled = [system.convert]::ToString($ACEnabled).ToLower()
	$rels.ace_policy = $ACPolicy

	return $rels
}

Function CreateVirtualMachineOSObj ($VMsTemp){ # Builds VM Obj and populates Arrays used to create chart

	Write-Host "          " Collecting Virtual Machine Guest OS information...

	# Calculate how many of each Guest OS
	$NumberOfWindowsVMs = $VMsTemp | Where-Object {$_.Guest -like "*Windows*"} | Measure-Object
	$NumberOfWindowsVMs = $NumberOfWindowsVMs.Count
	$NumberOfLinuxVMs = $VMsTemp | Where-Object {$_.Guest -like "*inux*" -OR $_.Guest -like "*nix*"} | Measure-Object
	$NumberOfLinuxVMs = $NumberOfLinuxVMs.Count
	$NumberOfOtherVMs = [int]$VMsTemp.Length - ([int]$NumberOfWindowsVMs + [int]$NumberOfLinuxVMs)

	$vms = @{}
	$vms.win = $NumberOfWindowsVMs
	$vms.nix = $NumberOfLinuxVMs
	$vms.other = $NumberOfOtherVMs
	$vms.total = $VMsTemp.Length

	# Populate Arrays to create Chart
	$global:ArrayOfNames += "Windows"
	$global:ArrayOfNames += "Linux/Unix"
	$global:ArrayOfNames += "Other"
	$global:ArrayOfValues += $NumberOfWindowsVMs
	$global:ArrayOfValues += $NumberOfLinuxVMs
	$global:ArrayOfValues += $NumberOfOtherVMs

	return $vms
}


################################################# OUTPUT ##########################################################

######################## INVENTORY ############################

Write-Host Step 1/6 - Collecting inventory...


#Start building the JSON Object
$json.timestamp = [Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))
$json.description = "VMWare Capacity & Performance Report for " + $vCenterServerName

#Populate the Metadata and Hardware Information
$json.servers = @{}
$json.servers.$vCenterServerName = @{}

$servers = $json.servers.$vCenterServerName
$servers.metadata = ListVCenterInventory

$servers.hardware = @{}
$servers.hardware = BuildESXiSoftwareAndHardwareInfoObj ($VMHosts)


######################## vCenter CPU CAPACITY REPORT ############################

Write-Host Step 2/6 - Collecting CPU statistics...

$servers.cpu = @{}
$servers.cpu = CreateVMHostCPUUsageObj ($VMHosts)

# CLEANUP
ReinitializeArrays


######################## vCenter MEMORY CAPACITY REPORT ############################

Write-Host Step 3/6 - Collecting Memory information...

$servers.memory = @{}
$servers.memory = CreateVMHostMemoryUsageObj ($VMHosts)

# CLEANUP
ReinitializeArrays


######################## vCenter DATASTORE CAPACITY REPORT ############################

Write-Host Step 4/6 - Collecting Datastore information...

$servers.datastore = @{}
$servers.datastore = CreateDatastoreUsageObj ($Datastores)

# CLEANUP
ReinitializeArrays


######################## vCenter VIRTUAL MACHINE REPORT ############################

Write-Host Step 5/6 - Collecting Virtual Machine information...

$servers.vms = @{}
$servers.vms =  CreateVirtualMachineOSObj ($VM)

# CLEANUP
ReinitializeArrays


########################  PER CLUSTER REPORT ############################

Write-Host Step 6/6 - Collecting Cluster information...

$json.clusters = @{}
$cluster = $json.clusters

# Loop through all clusters
ForEach ($ClusterTemp in ($Clusters)){

	$NumberOfVMHostsInCluster = $ClusterTemp | Get-VMHost | Measure-Object
	$NumberOfVMHostsInCluster = $NumberOfVMHostsInCluster.Count

	If ($NumberOfVMHostsInCluster -gt 1){ #Ignore Clusters with no ESXi hosts in it

		Write-Host "          " Gathering $ClusterTemp.Name "usage statistics..."


		$VMHostsInCluster = $ClusterTemp | Get-VMHost
		$DatastoresInCluster = $ClusterTemp | Get-VMHost | Get-Datastore
		$VMsInCluster = $ClusterTemp | Get-VM

		$vCenterClusterName = $ClusterTemp.Name.ToLower() -replace " ", "_"

		$cluster.$vCenterClusterName = @{}

		################################# PER CLUSTER INVENTORY  ##########################
		$cluster.$vCenterClusterName.hardware = @{}
		$cluster.$vCenterClusterName.hardware = ListClusterInventory ($ClusterTemp)


		################################# PER CLUSTER CPU REPORT ##########################
		$cluster.$vCenterClusterName.hardware = @{}
		$cluster.$vCenterClusterName.hardware = CreateVMHostCPUUsageObj ($VMHostsInCluster)

		# CLEANUP
		ReinitializeArrays

		################################# PER CLUSTER MEMORY REPORT ##########################
		$cluster.$vCenterClusterName.memory = @{}
		$cluster.$vCenterClusterName.memory = CreateVMHostMemoryUsageObj ($VMHostsInCluster)

		# CLEANUP
		ReinitializeArrays

		################################# PER CLUSTER DATASTORE REPORT ##########################
		$cluster.$vCenterClusterName.datastore = @{}
		$cluster.$vCenterClusterName.datastore = CreateDatastoreUsageObj ($DatastoresInCluster)

		# CLEANUP
		ReinitializeArrays


		################################# PER CLUSTER PROVISONING POTENTIAL REPORT ##########################
		$cluster.$vCenterClusterName.provisioning = @{}
		$cluster.$vCenterClusterName.provisioning = CreateClusterProvisioningPotentialObjs ($ClusterTemp)




		################################# PER CLUSTER RESILIENCE REPORT ##########################
		$cluster.$vCenterClusterName.resilency = @{}
		$cluster.$vCenterClusterName.resilency = CreateClusterResilienceObj ($ClusterTemp)

		# CLEANUP
		ReinitializeArrays


	}
}


########################### Outpu JSON #################################
Write-Output $json | ConvertTo-Json -Depth 5 | Out-File ((Get-Location).Path + "\report.json"
Write-Host "Report has exported to " + ((Get-Location).Path + "\report.json")



Exit
