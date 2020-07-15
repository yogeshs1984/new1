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
