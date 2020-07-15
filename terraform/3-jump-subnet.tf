# Jump-server Subnet 
resource "azurerm_subnet" "jumpSubnet" {
  name                 = "${azurerm_resource_group.tf.name}-jump-subnet"
  resource_group_name  = azurerm_resource_group.tf.name
  virtual_network_name = azurerm_virtual_network.tf.name
  address_prefix       = "10.1.1.0/24"
}


# Create network security group for jump-server 

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


# attach to subnet

resource "azurerm_subnet_network_security_group_association" "jumpSubnet" {
  subnet_id                 = azurerm_subnet.jumpSubnet.id
  network_security_group_id = azurerm_network_security_group.jumpSubnet.id
}



# jump-server Loadbalancer

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

# which server to add here -> frontend LoadBalancer IP

resource "azurerm_lb_backend_address_pool" "jumpserverbackendpool" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.jumpserverlb.id
 name                = "${azurerm_resource_group.tf.name}-jump-server-loadbalancer-BackEndAddress"
}

# to monitor ports are available or not 

resource "azurerm_lb_probe" "jumpservervmss" {
 resource_group_name = azurerm_resource_group.tf.name
 loadbalancer_id     = azurerm_lb.jumpserverlb.id
 name                = "ssh-running-probe"
 port                = 22
}

# LoadBalacing Rule for LoadBalancer

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


# create network interface for VM, attached to jump-server subnet

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


# create availability set

resource "azurerm_availability_set" "jumpavset" {
 name                         = "${azurerm_resource_group.tf.name}-jump-server-availability-set"
 location                     = azurerm_resource_group.tf.location
 resource_group_name          = azurerm_resource_group.tf.name
 platform_fault_domain_count  = 1
 platform_update_domain_count = 1
 managed                      = true
}


# assign availability set attached to VM 

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