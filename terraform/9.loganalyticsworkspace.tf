resource "azurerm_log_analytics_workspace" "tf" {
  name                = "${azurerm_resource_group.tf.name}-log-analytics-workspace"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
