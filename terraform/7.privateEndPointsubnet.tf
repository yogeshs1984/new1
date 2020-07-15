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
