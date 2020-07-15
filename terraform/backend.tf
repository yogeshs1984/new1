terraform {
  backend "azurerm" {
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
    access_key           = var.access_key
    key                  = var.key
    resource_group_name  = var.backend_resource_group_name
  }
}

variable "storage_account_name" {}
variable "container_name" {}
variable "access_key" {}
variable "key" {}
variable "backend_resource_group_name" {}