provider "azurerm" {
    features {}
    version = "=2.5.0"
      # subscription_id = "40fc8367-71d9-465f-9ce5-77dba3008cb4"
      # client_id       = "92229412-7e97-4d4c-b5b0-6abc1bce6b59"
      # client_secret   = "eaF-RO74ASTF4Akv3fX3T6TZ8PK_ud1lEL"
      # tenant_id       = "378f7e1e-4cb7-4e2b-a141-a5719085c679"
}


# pre requiremnets
# resource group
# keyvault
# Backend Storage account

resource "azurerm_resource_group" "tf" {
  name     = "${var.azure_resource_group}-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "tf" {
  name                = "${azurerm_resource_group.tf.name}-vnet"
  address_space       = [var.virtual_networks]
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  tags                = var.tags
}

# Jump server Subnet 

resource "azurerm_subnet" "jumpSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-jump-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.1.0/24"
}

resource "azurerm_network_security_group" "jumpSubnet" {
  name                = "${azurerm_subnet.jumpSubnet.name}-securityGroup"
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

resource "azurerm_subnet_network_security_group_association" "jumpSubnet" {
  subnet_id                 = azurerm_subnet.jumpSubnet.id
  network_security_group_id = azurerm_network_security_group.jumpSubnet.id
}

# jump-server configuration

resource "azurerm_lb" "jumpserverlb" {
  name                = "${azurerm_resource_group.tf.name}-jump-server-LoadBalancer"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${azurerm_resource_group.tf.name}-jump-server-loadbalancer-FrontEndAddress"
    subnet_id            = azurerm_subnet.jumpSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "jumpserverbackendpool" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.jumpserverlb.id
 name                = "${azurerm_resource_group.tf.name}-jump-server-loadbalancer-BackEndAddress"
}

resource "azurerm_lb_probe" "jumpservervmss" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.jumpserverlb.id
 name                = "ssh-running-probe"
 port                = 22
}

resource "azurerm_lb_rule" "lbnatrule" {
   resource_group_name            = azurerm_resource_group.tf.name
   loadbalancer_id                = azurerm_lb.jumpserverlb.id
   name                           = "SSH"
   protocol                       = "Tcp"
   frontend_port                  = 22
   backend_port                   = 22
   backend_address_pool_id        = azurerm_lb_backend_address_pool.jumpserverbackendpool.id
   frontend_ip_configuration_name = "${azurerm_resource_group.tf.name}-jump-server-loadbalancer-FrontEndAddress"
   probe_id                       = azurerm_lb_probe.jumpservervmss.id
}



resource "azurerm_network_interface" "testjump" {
 count               = 1
 name                = "${azurerm_resource_group.tf.name}-jump-server-interface-00${count.index + 1}"
 location            = azurerm_resource_group.tf.location
 resource_group_name = azurerm_resource_group.tf.name
 ip_configuration {
   name                          = "${azurerm_resource_group.tf.name}-jump-server-interface-Configuration"
   subnet_id                     = azurerm_subnet.jumpSubnet.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_availability_set" "jumpavset" {
 name                         = "${azurerm_resource_group.tf.name}-jump-server-availability-set"
 location                     = azurerm_resource_group.tf.location
 resource_group_name          = azurerm_resource_group.tf.name
 platform_fault_domain_count  = 1
 platform_update_domain_count = 1
 managed                      = true
}

# resource "azurerm_managed_disk" "testdisk" {
#  count                = 2
#  name                 = "oracle-server-datadisk-00${count.index + 1}"
#  location             = azurerm_resource_group.tf.location
#  resource_group_name  = azurerm_resource_group.tf.name
#  storage_account_type = "Standard_LRS"
#  create_option        = "Empty"
#  disk_size_gb         = "10"
# }


resource "azurerm_virtual_machine" "jumpservers" {
 count                 = 1
 name                  = "${azurerm_resource_group.tf.name}-jump-server-00${count.index + 1}"
 location              = azurerm_resource_group.tf.location
 resource_group_name   = azurerm_resource_group.tf.name
  availability_set_id  = azurerm_availability_set.jumpavset.id
 network_interface_ids = [element(azurerm_network_interface.testjump.*.id, count.index)]
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
   name              = "${azurerm_resource_group.tf.name}-jump-server-osdisk-00${count.index + 1}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

#  # Optional data disks
#  storage_data_disk {
#    name              = "datadisk-jumpserver-${count.index + 1}"
#    managed_disk_type = "Standard_LRS"
#    create_option     = "Empty"
#    lun               = 0
#    disk_size_gb      = "10"
#  }

#  storage_data_disk {
#    name            = element(azurerm_managed_disk.testdisk.*.name, count.index)
#    managed_disk_id = element(azurerm_managed_disk.testdisk.*.id, count.index)
#    create_option   = "Attach"
#    lun             = 1
#    disk_size_gb    = element(azurerm_managed_disk.testdisk.*.disk_size_gb, count.index)
#  }



 os_profile {
   computer_name  = "${azurerm_resource_group.tf.name}-jump-server-00${count.index + 1}"
   admin_username = "node"
   admin_password = "Password@123"
 }
 os_profile_linux_config {
   disable_password_authentication = false
 }
  tags                = var.tags
}


resource "azurerm_network_interface_backend_address_pool_association" "vaultthree" {
  count                   = 1
  network_interface_id    = element(azurerm_network_interface.testjump.*.id, count.index)
  ip_configuration_name   = "${azurerm_resource_group.tf.name}-jump-server-interface-Configuration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.jumpserverbackendpool.id
}

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


# azure kuberntes Subnet 

resource "azurerm_subnet" "aksSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-kubernetes-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.2.0/24"
}


resource "azurerm_network_security_group" "aksSubnet" {
  name                = "${azurerm_subnet.aksSubnet.name}-securityGroup"
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


resource "azurerm_subnet_network_security_group_association" "aksSubnet" {
  subnet_id                 = azurerm_subnet.aksSubnet.id
  network_security_group_id = azurerm_network_security_group.aksSubnet.id
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



















































# Private EndPoint Subnet

resource "azurerm_subnet" "peSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-privateEndPoint-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.4.0/24"
}

resource "azurerm_network_security_group" "peSubnet" {
  name                = "${azurerm_subnet.peSubnet.name}-securityGroup"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  tags                = var.tags
  security_rule {
    name                       = "InMainRule_1"
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


resource "azurerm_subnet_network_security_group_association" "peSubnet" {
  subnet_id                 = azurerm_subnet.peSubnet.id
  network_security_group_id = azurerm_network_security_group.peSubnet.id
}



# Private Link Service Subnet

resource "azurerm_subnet" "plsSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-privateLinkService-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.5.0/24"
}

resource "azurerm_network_security_group" "plsSubnet" {
  name                = "${azurerm_subnet.plsSubnet.name}-securityGroup"
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

resource "azurerm_subnet_network_security_group_association" "plsSubnet" {
  subnet_id                 = azurerm_subnet.plsSubnet.id
  network_security_group_id = azurerm_network_security_group.plsSubnet.id
}



# FireWall Subnet

resource "azurerm_subnet" "FwSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-fireWall-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.6.0/24"
}


resource "azurerm_network_security_group" "FwSubnet" {
  name                = "${azurerm_subnet.FwSubnet.name}-securityGroup"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  tags                = var.tags
  security_rule {
    name                       = "InMainRule_1"
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


resource "azurerm_subnet_network_security_group_association" "FwSubnet" {
  subnet_id                 = azurerm_subnet.FwSubnet.id
  network_security_group_id = azurerm_network_security_group.FwSubnet.id
}



resource "azurerm_log_analytics_workspace" "tf" {
  name                = "${azurerm_resource_group.tf.name}-log-analytics-workspace"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}


resource "azurerm_storage_account" "tf" {
  name                     = "testjjstorageaccountname"
  resource_group_name      = azurerm_resource_group.tf.name
  location                 = azurerm_resource_group.tf.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
  network_rules {
    default_action         = "Deny"
    bypass                 = ["None"]
    virtual_network_subnet_ids = [azurerm_subnet.dbSubnet.id]
  }
}


# Pass Service details

resource "azurerm_storage_account" "oraclestorageaccount" {
  name                     = replace("${azurerm_resource_group.tf.name}-mongodbstrgac", "-", "")
  resource_group_name      = azurerm_resource_group.tf.name
  location                 = azurerm_resource_group.tf.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
    network_rules {
    virtual_network_subnet_ids = [azurerm_subnet.dbSubnet.id]
    bypass                     = ["None"]
    default_action             = "Deny"
  }
}

resource "azurerm_storage_account" "diagnosticstorageaccount" {
  name                     = replace("${azurerm_resource_group.tf.name}-diagnostrgac", "-", "")
  resource_group_name      = azurerm_resource_group.tf.name
  location                 = azurerm_resource_group.tf.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    virtual_network_subnet_ids = [azurerm_subnet.dbSubnet.id]
    bypass                     = ["None"]
    default_action             = "Deny"
  }
}


resource "azurerm_storage_account" "mongodbstorageaccount" {
  name                     = replace("${azurerm_resource_group.tf.name}-oracledbstrgeac", "-", "")
  resource_group_name      = azurerm_resource_group.tf.name
  location                 = azurerm_resource_group.tf.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  network_rules {
    virtual_network_subnet_ids = [azurerm_subnet.dbSubnet.id]
    bypass                     = ["None"]
    default_action             = "Deny"
  }
}


variable "environment" {
    default = "test"
}

variable "azure_resource_group" {
    default = "demo"
}

variable "virtual_networks" {
    default = "10.1.0.0/16"
}

variable "location" {
    default = "eastus"
}

variable "oracledbCount" {
    default = "1"
}

variable "mongodbCount" {
    default = "1"
}


variable "tags" {
  type = map
  default = {
    envronment    = "test"
    provision_by  = "terraform"
  }
}



# https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/oms-linux
# https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-cluster-with-infrastructure
# https://www.pulumi.com/docs/reference/pkg/azure/storage/account/
# https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-scaleset-network-disks-hcl
