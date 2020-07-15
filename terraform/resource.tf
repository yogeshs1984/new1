provider "azurerm" {
    features {}
    version = "=2.5.0"

}

terraform {
  backend "azurerm" {

  }
}
resource "azurerm_resource_group" "tf" {
  name     = "${var.azure_resource_group}-${var.environment}"
  location = var.location
  tags     = var.tags
}

variable "environment" {}
variable "azure_resource_group" {
    default = "demo"
}
variable "location" {
    default = "eastus"
}

variable "tags" {
  type = map
  default = {
    envronment    = "test"
    provision_by  = "terraform"
  }
}
