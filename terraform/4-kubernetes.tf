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

resource "azurerm_kubernetes_cluster" "tf" {
  name                = "${azurerm_resource_group.tf.name}-kubernetes-service"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  dns_prefix          = var.dns_prefix

  linux_profile {
    admin_username = "ubuntu"
    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  default_node_pool {
    name                = "${azurerm_resource_group.tf.name}-kubernetes-service-pool"
    enable_auto_scaling = true
    type                = "VirtualMachineScaleSets"
    min_count           = 1
    max_count           = 2
    vm_size             = "Standard_DS1_v2"
    os_disk_size_gb     = 100
    max_pods            = 250
    vnet_subnet_id      = azurerm_subnet.aksSubnet.id
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "10.240.0.0/16"
    dns_service_ip     = "10.240.0.10"
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.tf.id
    }
  }
  tags = var.tags
}