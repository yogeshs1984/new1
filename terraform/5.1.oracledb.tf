# Oracle server configuration

resource "azurerm_lb" "oracledbserverlb" {
  name                = "${azurerm_resource_group.tf.name}-oracledb-server-LoadBalancer"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${azurerm_resource_group.tf.name}-oracledb-server-loadbalancer-FrontEndAddress"
    subnet_id            = azurerm_subnet.dbSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "oraclebackendpool" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.oracledbserverlb.id
 name                = "${azurerm_resource_group.tf.name}-oracledb-server-loadbalancer-BackEndAddress"
}

resource "azurerm_lb_probe" "oraclevmss" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.oracledbserverlb.id
 name                = "ssh-running-probe"
 port                = 22
}

resource "azurerm_lb_rule" "oraclelbnatrule" {
   resource_group_name            = azurerm_resource_group.tf.name
   loadbalancer_id                = azurerm_lb.oracledbserverlb.id
   name                           = "SSH"
   protocol                       = "Tcp"
   frontend_port                  = 22
   backend_port                   = 22
   backend_address_pool_id        = azurerm_lb_backend_address_pool.oraclebackendpool.id
   frontend_ip_configuration_name = "${azurerm_resource_group.tf.name}-oracledb-server-loadbalancer-FrontEndAddress"
   probe_id                       = azurerm_lb_probe.oraclevmss.id
}



resource "azurerm_network_interface" "testone" {
 count               = var.oracledbCount
 name                = "${azurerm_resource_group.tf.name}-oracledb-server-interface-00${count.index + 1}"
 location            = azurerm_resource_group.tf.location
 resource_group_name = azurerm_resource_group.tf.name
 ip_configuration {
   name                          = "${azurerm_resource_group.tf.name}-oracledb-server-interface-Configuration"
   subnet_id                     = azurerm_subnet.dbSubnet.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_availability_set" "oracleavset" {
 name                         = "${azurerm_resource_group.tf.name}-oracledb-server-availability-set"
 location                     = azurerm_resource_group.tf.location
 resource_group_name          = azurerm_resource_group.tf.name
 platform_fault_domain_count  = var.oracledbCount
 platform_update_domain_count = var.oracledbCount
 managed                      = true
}

resource "azurerm_managed_disk" "testdisk" {
 count                = var.oracledbCount
 name                 = "${azurerm_resource_group.tf.name}-oracledb-server-DataDisk-00${count.index + 1}"
 location             = azurerm_resource_group.tf.location
 resource_group_name  = azurerm_resource_group.tf.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "10"
}


resource "azurerm_virtual_machine" "oracleservers" {
 count                 = var.oracledbCount
 name                  = "${azurerm_resource_group.tf.name}-oracledb-server-00${count.index + 1}"
 location              = azurerm_resource_group.tf.location
 resource_group_name   = azurerm_resource_group.tf.name
 availability_set_id  = azurerm_availability_set.oracleavset.id
 network_interface_ids = [element(azurerm_network_interface.testone.*.id, count.index)]
 vm_size               = "Standard_DS1_v2"

 # Uncomment this line to delete the OS disk automatically when deleting the VM
 # delete_os_disk_on_termination = true

 # Uncomment this line to delete the data disks automatically when deleting the VM
 # delete_data_disks_on_termination = true

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "${azurerm_resource_group.tf.name}-oracledb-server-osdisk-00${count.index + 1}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

## Optional data disks
#  storage_data_disk {
#    name              = "datadisk-hostname-${count.index + 1}"
#    managed_disk_type = "Standard_LRS"
#    create_option     = "Empty"
#    lun               = 0
#    disk_size_gb      = "10"
#  }

 storage_data_disk {
   name            = element(azurerm_managed_disk.testdisk.*.name, count.index)
   managed_disk_id = element(azurerm_managed_disk.testdisk.*.id, count.index)
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = element(azurerm_managed_disk.testdisk.*.disk_size_gb, count.index)
 }



 os_profile {
   computer_name  = "${azurerm_resource_group.tf.name}-oracledb-server-00${count.index + 1}"
   admin_username = "node"
   admin_password = "Password@123"
 }
 os_profile_linux_config {
   disable_password_authentication = false
 }
  tags                = var.tags
}


resource "azurerm_network_interface_backend_address_pool_association" "vaulttwo" {
  count                   = var.oracledbCount
  network_interface_id    = element(azurerm_network_interface.testone.*.id, count.index)
  ip_configuration_name   = "${azurerm_resource_group.tf.name}-oracledb-server-interface-Configuration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.oraclebackendpool.id
}

