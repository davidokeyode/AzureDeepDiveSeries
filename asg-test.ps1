Get-Command *ApplicationSecurityGroup*
Get-AzureRmApplicationSecurityGroup
New-AzureRmApplicationSecurityGroup
Remove-AzureRmApplicationSecurityGroup


$rg = "asg-rg-01"
$loc = "westeurope"
$webAsgName = "myAsgWebServers"
$mgmtAsgName = "myAsgMgmtServers"
$nsgName = "myNsg01"
$vNetName = "myVirtualNetwork01"
$vNetPrefix = "10.10.0.0/16"
$subnetName = "mySubnet01"
$subnetPrefix = "10.10.2.0/24"
$webNicName = "myVmWeb01"
$mgmtNicName = "myVmMgmt01"
$webVmName = "myVmWeb01"
$mgmtVmName = "myVmMgmt01"
$vmSize = "Standard_D2_V2"

# Create resource group
New-AzureRmResourceGroup -ResourceGroupName $rg -Location $loc

# Create application security groups
$webAsg = New-AzureRmApplicationSecurityGroup `
  -ResourceGroupName $rg `
  -Name $webAsgName `
  -Location $loc

$mgmtAsg = New-AzureRmApplicationSecurityGroup `
  -ResourceGroupName $rg `
  -Name $mgmtAsgName `
  -Location $loc

# Create security rules
# The following example creates a rule that allows traffic inbound from the internet to the myWebServers application security group over ports 80 and 443:
$webRule = New-AzureRmNetworkSecurityRuleConfig `
  -Name "Allow-Web-All" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 100 `
  -SourceAddressPrefix Internet `
  -SourcePortRange * `
  -DestinationApplicationSecurityGroupId $webAsg.id `
  -DestinationPortRange 80,443

# The following example creates a rule that allows traffic inbound from the internet to the *myMgmtServers* application security group over port 3389:
$mgmtRule = New-AzureRmNetworkSecurityRuleConfig `
  -Name "Allow-RDP-All" `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 110 `
  -SourceAddressPrefix Internet `
  -SourcePortRange * `
  -DestinationApplicationSecurityGroupId $mgmtAsg.id `
  -DestinationPortRange 3389


# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup `
  -ResourceGroupName $rg `
  -Location $loc `
  -Name $nsgName `
  -SecurityRules $webRule,$mgmtRule


# Create a virtual network
$virtualNetwork = New-AzureRmVirtualNetwork `
  -ResourceGroupName $rg `
  -Location $loc `
  -Name $vNetName `
  -AddressPrefix $vNetPrefix


# Create subnet config
Add-AzureRmVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -VirtualNetwork $virtualNetwork `
  -AddressPrefix $subnetPrefix `
  -NetworkSecurityGroup $nsg
$virtualNetwork | Set-AzureRmVirtualNetwork


# Create vm
$virtualNetwork = Get-AzureRmVirtualNetwork `
 -Name $vNetName `
 -Resourcegroupname $rg

# Create public IP addresses
$publicIpWeb = New-AzureRmPublicIpAddress -AllocationMethod Dynamic -ResourceGroupName $rg -Location $loc -Name $webVmName
$publicIpMgmt = New-AzureRmPublicIpAddress -AllocationMethod Dynamic -ResourceGroupName $rg -Location $loc -Name $mgmtVmName


$webNic = New-AzureRmNetworkInterface `
  -Location $loc `
  -Name $webNicName `
  -ResourceGroupName $rg `
  -SubnetId $virtualNetwork.Subnets[0].Id `
  -ApplicationSecurityGroupId $webAsg.Id `
  -PublicIpAddressId $publicIpWeb.Id

$mgmtNic = New-AzureRmNetworkInterface `
  -Location $loc `
  -Name $mgmtNicName `
  -ResourceGroupName $rg `
  -SubnetId $virtualNetwork.Subnets[0].Id `
  -ApplicationSecurityGroupId $mgmtAsg.Id `
  -PublicIpAddressId $publicIpMgmt.Id

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create VM that will serve as a web server
$webVmConfig = New-AzureRmVMConfig `
  -VMName $webVmName `
  -VMSize $vmSize | `
Set-AzureRmVMOperatingSystem -Windows `
  -ComputerName $webVmName `
  -Credential $cred | `
Set-AzureRmVMSourceImage `
  -PublisherName MicrosoftWindowsServer `
  -Offer WindowsServer `
  -Skus 2016-Datacenter `
  -Version latest | `
Add-AzureRmVMNetworkInterface `
  -Id $webNic.Id
New-AzureRmVM `
  -ResourceGroupName $rg `
  -Location $loc `
  -VM $webVmConfig `
  -AsJob


# Create VM that will serve as a management server
$mgmtVmConfig = New-AzureRmVMConfig `
  -VMName $mgmtVmName `
  -VMSize $vmSize | `
Set-AzureRmVMOperatingSystem -Windows `
  -ComputerName $mgmtVmName `
  -Credential $cred | `
Set-AzureRmVMSourceImage `
  -PublisherName MicrosoftWindowsServer `
  -Offer WindowsServer `
  -Skus 2016-Datacenter `
  -Version latest | `
Add-AzureRmVMNetworkInterface `
  -Id $mgmtNic.Id
New-AzureRmVM `
  -ResourceGroupName $rg `
  -Location $loc `
  -VM $mgmtVmConfig

Get-AzureRmPublicIpAddress `
  -Name $webVmName `
  -ResourceGroupName $rg `
  | Select IpAddress

Get-AzureRmPublicIpAddress `
  -Name $mgmtVmName `
  -ResourceGroupName $rg `
  | Select IpAddress



























