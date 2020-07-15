variable "environment" {} # runtime variable

variable "azure_resource_group" {
    default = "demo"
}

variable "virtual_networks" {
    default = "10.1.0.0/16"
}

variable "location" {
    default = "westus2"
}

variable "oracledbCount" {
    default = "1"
}

variable "mongodbCount" {
    default = "1"
}


variable "tags" {
  type = map
  default = {
    envronment    = "test"
    provision_by  = "terraform"
  }
}
