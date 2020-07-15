
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














# https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/oms-linux
# https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-cluster-with-infrastructure
# https://www.pulumi.com/docs/reference/pkg/azure/storage/account/
# https://docs.microsoft.com/en-us/azure/developer/terraform/create-vm-scaleset-network-disks-hcl
