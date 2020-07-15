resource "azurerm_subnet" "dbSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-dataBase-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.3.0/24"
  service_endpoints    = ["Microsoft.Sql","Microsoft.Storage","Microsoft.KeyVault"]
}

resource "azurerm_network_security_group" "dbSubnet" {
  name                = "${azurerm_subnet.dbSubnet.name}-securityGroup"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  tags                = var.tags
  security_rule {
    name                       = "All"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dbSubnet" {
  subnet_id                 = azurerm_subnet.dbSubnet.id
  network_security_group_id = azurerm_network_security_group.dbSubnet.id
}




# Mongodb server co0nfiguration

resource "azurerm_lb" "mongodbserverlb" {
  name                = "${azurerm_resource_group.tf.name}-mongodb-server-LoadBalancer"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${azurerm_resource_group.tf.name}-mongodb-server-loadbalancer-FrontEndAddress"
    subnet_id            = azurerm_subnet.dbSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.mongodbserverlb.id
 name                = "${azurerm_resource_group.tf.name}-mongodb-server-loadbalancer-BackEndAddress"
}

resource "azurerm_lb_probe" "vmss" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.mongodbserverlb.id
 name                = "ssh-running-probe"
 port                = 22
}

resource "azurerm_lb_rule" "mongolbrule" {
   resource_group_name            = azurerm_resource_group.tf.name
   loadbalancer_id                = azurerm_lb.mongodbserverlb.id
   name                           = "SSH"
   protocol                       = "Tcp"
   frontend_port                  = 22
   backend_port                   = 22
   backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
   frontend_ip_configuration_name = "${azurerm_resource_group.tf.name}-mongodb-server-loadbalancer-FrontEndAddress"
   probe_id                       = azurerm_lb_probe.vmss.id
}



resource "azurerm_network_interface" "test" {
 count               = var.mongodbCount
 name                = "${azurerm_resource_group.tf.name}-mongodb-server-interface-00${count.index + 1}"
 location            = azurerm_resource_group.tf.location
 resource_group_name = azurerm_resource_group.tf.name
 ip_configuration {
   name                          = "${azurerm_resource_group.tf.name}-mongodb-server-interface-Configuration"
   subnet_id                     = azurerm_subnet.dbSubnet.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_availability_set" "avset" {
 name                         = "${azurerm_resource_group.tf.name}-mongodb-server-availability-set"
 location                     = azurerm_resource_group.tf.location
 resource_group_name          = azurerm_resource_group.tf.name
 platform_fault_domain_count  = var.mongodbCount
 platform_update_domain_count = var.mongodbCount
 managed                      = true
}

resource "azurerm_managed_disk" "test" {
 count                = var.mongodbCount
 name                 = "${azurerm_resource_group.tf.name}-mongodb-server-DataDisk-00${count.index + 1}"
 location             = azurerm_resource_group.tf.location
 resource_group_name  = azurerm_resource_group.tf.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "10"
}


resource "azurerm_virtual_machine" "test" {
 count                 = var.mongodbCount
 name                  = "${azurerm_resource_group.tf.name}-mongodb-server-00${count.index + 1}"
 location              = azurerm_resource_group.tf.location
 resource_group_name   = azurerm_resource_group.tf.name
  availability_set_id   = azurerm_availability_set.avset.id
 network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
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
   name              = "${azurerm_resource_group.tf.name}-mongodb-server-osdisk-00${count.index + 1}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 # Optional data disks

#  storage_data_disk {
#    name              = "datadisk-hostname-${count.index + 1}"
#    managed_disk_type = "Standard_LRS"
#    create_option     = "Empty"
#    lun               = 0
#    disk_size_gb      = "10"
#  }

 storage_data_disk {
   name            = element(azurerm_managed_disk.test.*.name, count.index)
   managed_disk_id = element(azurerm_managed_disk.test.*.id, count.index)
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = element(azurerm_managed_disk.test.*.disk_size_gb, count.index)
 }



 os_profile {
   computer_name  = "${azurerm_resource_group.tf.name}-mongodb-server-00${count.index + 1}"
   admin_username = "node"
   admin_password = "Password@123"
 }
 os_profile_linux_config {
   disable_password_authentication = false
 }
  tags                = var.tags
}


resource "azurerm_network_interface_backend_address_pool_association" "vault" {
  count                   = var.mongodbCount
  network_interface_id    = element(azurerm_network_interface.test.*.id, count.index)
  ip_configuration_name   = "${azurerm_resource_group.tf.name}-mongodb-server-interface-Configuration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}

