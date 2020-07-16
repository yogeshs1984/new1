resource "azurerm_log_analytics_workspace" "tf" {
  name                = "${azurerm_resource_group.tf.name}-log-analytics-workspace"
  location            = azurerm_resource_group.tf.location
  resource_group_name = azurerm_resource_group.tf.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "test" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.tf.location
    resource_group_name   = azurerm_resource_group.tf.name
    workspace_resource_id = azurerm_log_analytics_workspace.tf.id
    workspace_name        = azurerm_log_analytics_workspace.tf.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}