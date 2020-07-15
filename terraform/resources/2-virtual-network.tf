
resource "azurerm_virtual_network" "tf" {
  name                = "${azurerm_resource_group.tf.name}-vnet"
  address_space       = [var.virtual_networks]
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  tags                = var.tags
}
