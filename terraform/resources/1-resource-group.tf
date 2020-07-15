resource "azurerm_resource_group" "tf" {
  name     = "${var.azure_resource_group}-${var.environment}"
  location = var.location
  tags     = var.tags
}
